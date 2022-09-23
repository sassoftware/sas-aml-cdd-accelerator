/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Nick Newbill (nick.newbill@sas.com)
/ PURPOSE      : Close EDD Review
/ DESCRIPTION  :
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ rv_dispId           The id of the disposition code in fdhmetadata
/                       - 103140: DOWNGRADE_TO_LOW 
/                       - 103141: DOWNGRADE_TO_MED
/                       - 103142: DEMARKET
/                       - 103143: RETAIN
/ rv_objectType       The object in fdhdata
/ rv_src              The source CSV file with list of reviews to close
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fdx_close_edd_review(rv_dispId=103142,
/                                rv_objectType=crr_edd_reviews,
/                                rv_src=/path/to/file.csv);
/--------------------------------------------------------------------------------------------------------------------
/ HISTORY
/--------------------------------------------------------------------------------------------------------------------
/ 09SEPT2022    ninewb    Initial Release
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_close_edd_review(rv_dispId=,rv_objectType=,rv_src=);

%put Input Path: &rv_src;

%if %sysfunc(fileexist(&rv_src)) %then
%let fid=%sysfunc(fopen(&rv_src));
%else
%put File &rv_src. does not exist.;

/* Import CSV file with list of reviews to close */
data clsrvw;
    %let _EFIERR_ = 0; /* set the ERROR detection macro variable */
    infile "&rv_src." delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 ;
    informat review_id $36. ;
    informat disposition_comment $500. ;
    format review_id $36. ;
    format disposition_comment $500. ;
    input review_id disposition_comment $;
    if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
run;

%goto MACRO_END;

/* Get Stored Object ID */
proc sql noprint;
    SELECT stored_object_id into :storedObjectId
    FROM fdhmeta.dh_stored_object
    WHERE table_nm="&rv_objectType";
quit;

%put NOTE: Stored Object ID: &storedObjectId.;

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: SQL to get Stored Object ID failed.;
    %goto MACRO_END;
%end;

/* Get Disposition Code */
proc sql noprint;
    SELECT code into :dispositionCode
    FROM fdhmeta.dh_reference_table_item
    WHERE field_id="&rv_dispId";
quit;

%put NOTE: Disposition Code: &dispositionCode.;

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: SQL to get Disposition Code failed.;
    %goto MACRO_END;
%end;

/* Determine listing of reviews that exist in the system */
proc sql; 
CREATE TABLE existing_reviews AS
    SELECT *
    FROM fdhdata.&rv_objectType a
    INNER JOIN clsrvw b
    ON a.edd_report_id = b.review_id
    WHERE a.Status = 'ACT';
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: SQL to populate existing reviews failed.;
    %goto MACRO_END;
%end;

/* Determine listing of reviews that do not exist in the system */
proc sql;
CREATE TABLE nonexisting_reviews AS
    SELECT review_id
    FROM clsrvw a
    WHERE a.review_id NOT IN (SELECT edd_report_id FROM existing_reviews);;
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: SQL to identify ineligible reviews failed.;
    %goto MACRO_END;
%end;

/* Share counts and results of none found */
proc sql noprint;
    SELECT count(*)
    INTO :rv_count
    FROM existing_reviews;
quit;

%put NOTE: Number of reviews to close: &rv_count.; 

proc sql noprint;
    SELECT COUNT(*)
    INTO :rvn_count
    FROM nonexisting_reviews;
quit;

%put NOTE: Number of reviews not in the system: &rvn_count.;

proc sql noprint;
    SELECT review_id
    INTO :rvn_noid separated by ','
    FROM nonexisting_reviews;
quit;

%put NOTE: IDs not found in the system: &rvn_noid.;

/* Close out job if there aren't any reviews to close */
%if &rv_count eq 0 %then %do;
    %put NOTE: No reviews in the system match the list provided.;
    %goto MACRO_END; 
%end;

/* Compile variable list off eligible reviews */
proc sql noprint;
    SELECT edd_report_id, disposition_comment
    INTO :edd_id1-:edd_id%trim(&rv_count),
         :edd_disp1-:edd_disp%trim(&rv_count)
    FROM existing_reviews;
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: Variable array creation failed.;
    %goto MACRO_END;
%end;

/* Start looping through reviews to close */
%do i=1 %to &rv_count.;
%put Iteration &i of &rv_count.;

%let edd_id=&&edd_id&i;
%let edd_disp=&&edd_disp&i;

%put Reading &edd_id. with disposition of &edd_disp.;

filename getedd "%syscunf(pathname(work))/geteddrvw_out.json";
%let url_edd_id=%sysfunc(urlencode(%qcmpres(&edd_id)));

%let cls_time=%sysfunc(time(),tod8.);
data _null_;
    cls_date=scan(strip(put("&sysdate9"d,mmddyyd10.)),3,'-') || '-' || scan(put("&sysdate9"d,mmddyyd10.),1,'-') || '-' || scan(put("&sysdate9"d,mmddyyd10.),2,'-') || 'T00:00:00' || cats(strip(put(tzoneoff()/3600,z3.)),':00');
    cls_bdate=scan(strip(put("&sysdate9"d,mmddyyd10.)),3,'-') || '-' || scan(put("&sysdate9"d,mmddyyd10.),1,'-') || '-' || scan(put("&sysdate9"d-1,mmddyyd10.),2,'-');
    cls_edate=scan(strip(put("&sysdate9"d,mmddyyd10.)),3,'-') || '-' || scan(put("&sysdate9"d,mmddyyd10.),1,'-') || '-' || scan(put("&sysdate9"d,mmddyyd10.),2,'-');
    cls_time = symget('cls_time');
    call symput("closed_dttm",cls_date);
    call symput("cls_end_dt",cls_edate);
    call symput("cls_begin_dt",cls_bdate);
run;

%put NOTE: Closure of &edd_id on &closed_dttm;

%fdx_get_json_values(object_type=&rv_objectType,object_id=&edd_id,object_key=edd_report_id,out_ds=edd_doc);

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: fdx_get_json_values macro failed.;
    %goto MACRO_END;
%end;

data edd_doc;
    set edd_doc;
    if column_name = 'closed_at_dttm' then
        do;
        value = "&closed_dttm";
        end;

    if column_name = 'review_begin_date' then
       do;
       value = "&cls_begin_dt";
       end;

    if column_name = 'review_end_date' then
       do;
       value = "&cls_end_dt";
       end;

    if column_name = 'Status' then
        do;
        value = "CLS";
        end;

    if column_name = 'alert_disposition' then
        do;
        value = "&dispositionCode";
        end;
    
if column_name = 'review_disposition_comment' then
        do;
        value = "&edd_disp";
        end;
run;

proc print data=edd_doc;
run;

%fdx_write_json_values(table_nm=edd_doc,object_type=&rv_objectType,object_id=%str(&edd_id),fileref=updtcrr);

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: fdx_write_json_values macro failed.;
    %goto MACRO_END;
%end;

/*lock document before updating*/
%fdx_ws_lock_doc(object_type=&rv_objectType,object_id=&edd_id);

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: fdx_ws_lock_doc macro failed.;
    %goto MACRO_END;
%end;

/*update document*/
filename out_crr "%sysfunc(pathname(work))/edd_update_out.txt";
%let url_edd_id = %sysfunc(urlencode(%qcmpres(&edd_id)));

%fdx_ws_put_doc_json(object_type=&rv_objectType, object_id=&url_edd_id, ws_in_json_fref=updtcrr, _ws_out_json_fref=out_crr);

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: fdx_ws_put_doc_json macro failed.;
    %goto MACRO_END;
%end;

/*unlock document after updating*/
%fdx_ws_unlock_doc(object_type=&rv_objectType, object_id=&edd_id);

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: fdx_ws_unlock_doc macro failed.;
    %goto MACRO_END;
%end;

/* Terminate Workflow */
%let entityId = %qcmpres(&storedObjectId.);
%let get_url = %str(svi-datahub/workflows/processes?filter=and(eq(entityId,&entityId.),eq(entityInstanceId,%22&url_edd_id.%22)));
%put NOTE: url_edd_id = &url_edd_id | get_url = &get_url;

%fdx_ws_http_get_json(url=%str(&get_url),_ws_http_code=resp_code,error_ind=N);

%fsccheckrc;
%if &bat_abort=Y %then %do;
    %put NOTE: fdx_ws_http_get_json macro failed.;
    %goto MACRO_END;
%end;

/*if no valid response*/
%if &resp_code ne 200 and &resp_code ne 201 %then %do;
    %put NOTE: Response is &resp_code - NO ACTIVE WORKFLOW FOR &edd_id.;
%end;

/*if get a valid response*/
%else %do;
    /*get worflow_id to pass as url parameter*/
    libname get_resp json fileref=ws_out;
    %let process_count=0;

    proc sql noprint;
    select count
    into :process_count
    from get_resp.root;
    quit;

    %put NOTE: We are in fact hitting this do;

    %if &process_count ne 0 %then %do;
        proc sql noprint;
        select count(*) into :active_item_count from get_resp.items where state not in ('COMPLETE','CANCELLED');
        quit;  
        %put NOTE: active_item_count is &active_item_count;
    %end;

    %if &active_item_count ne 0 %then %do;
        proc sql noprint;
	select 'svi-datahub' || href into :wf_url from get_resp.items_links il 
		inner join get_resp.items i
	        on i.ordinal_items=il.ordinal_items
		where upcase(il.rel)='CANCEL' and upcase(i.state) not in ('COMPLETE','CANCELLED');
	;quit;
	%put NOTE: wf_url = &wf_url.;
							
	%fsccheckrc;
	%if &bat_abort=Y %then %do;
	    %put NOTE: SQL to get wf_url from href failed.;
	    %goto MACRO_END;
	%end;

        /*cancel workflow*/
        %fdx_ws_http_delete_json(url=&wf_url,_ws_http_code=delete_code,error_ind=N);

        %fsccheckrc;
        %if &bat_abort=Y %then %do;
            %put NOTE: fdx_ws_http_delete_json macro failed.;
            %goto MACRO_END;
        %end;

        %if &delete_code = 204 %then %do;
            %put NOTE: Workflow for &edd_id successfully cancelled.;  
        %end;
        %else %do;
	    %put NOTE: fdx_ws_http_delete_json failed, workflow for &edd_id not cancelled.;
        %end;

    %end; /*end of condition if process_count ne 0 (has an active workflow)*/

    %else %do;
        %put NOTE: No active workflow for &edd_id..;
    %end; /*end of condition if process_count = 0 (no active workflow)*/

%end; /*end of valid response condition*/

%end;

%PUT NOTE: End of workflow closure loop.;

%MACRO_END:

%mend;

