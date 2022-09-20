/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Nick Newbill (nick.newbill@sas.com)
/ PURPOSE      : Create EDD Review
/ DESCRIPTION  :
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ objectTypeId        The object in fdhdata
/ rv_src              The source CSV file with list of reviews to close
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fdx_crrrvw_create_json(objectTypeId=crr_edd_reviews,
/                                  rv_src=/path/to/file.csv);
/--------------------------------------------------------------------------------------------------------------------
/ HISTORY
/--------------------------------------------------------------------------------------------------------------------
/ 09SEPT2022    ninewb    Initial Release
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_close_edd_review(objectTypeId=crr_edd_reviews,rv_src=);

%put Input Path: &rv_src;

%if %sysfunc(fileexist(&rv_src)) %then
%let fid=%sysfunc(fopen(&rv_src));
%else
%put File &rv_src. does not exist.;

/* Import CSV file with list of reviews to close */
data clsrvw;
    %let _EFIERR_ = 0; /* set the ERROR detection macro variable */
    infile "&rv_src." delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 ;
    informat edd_report_id $36. ;
    informat review_disposition_comment $500. ;
    format edd_report_id $36. ;
    format review_disposition_comment $500. ;
    input edd_report_id review_disposition_comment $;
    if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
run;

/* Determine listing of reviews that exist in the system */
proc sql; 
CREATE TABLE existing_reviews AS
    SELECT *
    FROM fdhdata.&objectTypeId a
    WHERE a.edd_report_id IN (SELECT edd_report_id FROM clsrvw);;
quit;

/* Determine listing of reviews that do not exist in the system */
proc sql;
CREATE TABLE nonexisting_reviews AS
    SELECT edd_report_id
    FROM clsrvw a
    WHERE a.edd_report_id NOT IN (SELECT edd_report_id FROM existing_reviews);;

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
    SELECT edd_report_id
    INTO :rvn_noid separated by ','
    FROM nonexisting_reviews;
quit;

%put NOTE: IDs not found in the system: &rvn_noid.;

proc sql noprint;
    SELECT edd_report_id, review_disposition_comment
    INTO :edd_id1-:edd_id%trim(&rv_count),
         :edd_disp1-:edd_disp%trim(&rv_count)
    FROM existing_reviews;
quit;



/* Start looping through reviews to close */
%do i=1 %to &rv_count.;
%put Iteration &i of &rv_count.;

%let edd_id=&&edd_id&i;
%let edd_disp=&&edd_disp&i;

%put Reading &edd_id. with disposition of &edd_disp.;

filename getedd "%syscunf(pathname(work))/geteddrvw_out.json";
%let url_edd_id=%sysfunc(urlencode(%qcmpres(&edd_id)));

%put Calling fdx_get_json_values macro.;

%fdx_get_json_values(object_type=&objectTypeId,object_id=&edd_id,object_key=edd_report_id,out_ds=edd_doc);


data edd_doc;
    set edd_doc;
/*
    if column_name = 'closed_at_dttm' then
        do;
        value = scan(strip(put("&_closed_dttm"d,mmddyyd10.)),3,'-') || '-' || scan(put("&_closed_dttm"d,mmddyyd10.),1,'-') || '-' || scan(put("&_closed_dttm"d,mmddyyd10.),2,'-') || 'T00:00:00.000' || cats(strip(put(tzoneoff()/3600,z3.)),':00');
        end;
*/
    if column_name = 'Status' then
        do;
        value = "CLS";
        end;

    if column_name = 'review_disposition_comment' then
        do;
        value = "&edd_disp.";
        end;
run;

proc print data=edd_doc;
run;

%fdx_write_json_values(table_nm=edd_doc,object_type=&objectTypeId,object_id=%str(&edd_id),fileref=updtcrr);

/*lock document before updating*/
%fdx_ws_lock_doc(object_type=&objectTypeId,object_id=&edd_id);

/*update document*/
filename out_crr "%sysfunc(pathname(worklib))/edd_update_out.txt";
%let url_edd_id = %sysfunc(urlencode(%qcmpres(&edd_id)));

*%fdx_ws_put_doc_json(object_type=&objectTypeId, object_id=&url_edd_id, ws_in_json_fref=updtcrr, _ws_out_json_fref=out_crr);

/*unlock document after updating*/
%fdx_ws_unlock_doc(object_type=&objectTypeId, object_id=&edd_id);

/* Terminate Workflow */
%let entityId = %qcmpres(&objectTypeId);
%let get_url = %str(svi-datahub/workflows/processes?filter=and(eq(entityId,&entityId.),eq(entityInstanceId,%22&url_edd_id.%22)));
%put NOTE: url_crrrvw_id = &url_crrrvw_id | get_url = &get_url;


%end;


%mend;

