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
/ rv_queue            The queue we will disposition alerts for
/ rv_rel              The object_relationship_nm for our relationship id
/ rv_desc             The description supplied for each populated review
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fdx_create_edd_review(rv_queue=crr_high_scores_queue,
/                                 rv_rel=PTY,
/                                 rv_desc=);
/--------------------------------------------------------------------------------------------------------------------
/ HISTORY
/--------------------------------------------------------------------------------------------------------------------
/ 09SEPT2022    ninewb    Initial Release
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_create_edd_review(rv_queue=,rv_rel=,rv_desc=);

%local rv_queue rv_rel rv_desc;

/* Validate paramters */
%if %length(&rv_queue) eq 0 %then %do;
	%put ERROR: A queue was not specified.;
        %goto MACRO_END;
%end;
%if %length(&rv_rel) eq 0 %then %do;
	%let rv_rel=109514;
%end;
%if %length(&rv_desc) eq 0 %then %do;
	%let rv_desc=%str(Auto processed to EDD Review through batch creation execution.);
%end;

/* This a collection of all alerts that have existing active reviews */
proc sql;
create table disp_to_existing as
    SELECT DISTINCT a.alert_id,a.actionable_entity_id, c.edd_report_id
	FROM alerts.tdc_alert a
	INNER JOIN alerts.tdc_alerting_event b
	ON a.alert_id=b.alert_id
    INNER JOIN fdhdata.crr_edd_reviews c
        ON a.actionable_entity_id=c.actionable_entity_id
        AND c.Status='ACT'
	WHERE a.domain_id='crr_domain' 
	AND a.alert_status_id='ACTIVE';
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to get count of alerts dispositioned to existing reviews;
   %goto MACRO_END;
%end;


/* All high alerts that do not have existing active reviews */
proc sql;
create table disp_to_new as
    SELECT DISTINCT a.alert_id,a.actionable_entity_id,d.employee_ind
	FROM alerts.tdc_alert a
	INNER JOIN alerts.tdc_alerting_event b
	ON a.alert_id=b.alert_id
    LEFT JOIN fdhdata.crr_edd_reviews c
        ON a.actionable_entity_id=c.actionable_entity_id
        AND c.Status='ACT'
    INNER JOIN corevw.party_dim d
        ON a.actionable_entity_id=d.party_number
	WHERE a.domain_id='crr_domain' 
	AND a.alert_status_id='ACTIVE'
        AND c.actionable_entity_id IS MISSING
        AND a.queue_id=&rv_queue.;
/*        AND a.curr_score_val=&score_threshold.; */
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to get count of high alerts that do not have existing active reviews;
   %goto MACRO_END;
%end;

/* Get count of alerts to be dispositioned to an existing review */
proc sql noprint;
SELECT COUNT(*) INTO: altextcnt FROM disp_to_existing;
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to get count of alerts dispositioned to existing reviews;
   %goto MACRO_END;
%end;

%let adispcnt=&altextcnt;
%put NOTE: Count of alerts to be dispositioned to an existing review altextcnt=&altextcnt;

%if &altextcnt eq 0 %then %do;
    %put NOTE: No new alerts need to be dispostioned to an existing reviews.;
    %goto DISP_NEW;
%end;

/* Get numbered macro variables to loop through */
proc sql noprint;
SELECT alert_id,edd_report_id INTO :alert_id1-:alert_id%trim(&altextcnt),:edd_id1-:edd_id%trim(&altextcnt) FROM disp_to_existing;
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to get macro vars of alerts dispositioned to existing reviews.;
   %goto MACRO_END;
%end;

/* Loop through each alert in disp_to_existing and disposition to existing review */
%do i=1 %to &altextcnt;

%let alert_id=&&alert_id&i;
%let edd_id=&&edd_id&i;
%let alert_url=/svi-alert/alerts/&alert_id;

/* Get current modifiedTimeStamp from alert service*/
%fdx_ws_http_get_json(url=&alert_url, _ws_http_code=http_ret_code, _ws_out_json_fref=cc_out);
libname get_resp json fileref=ws_out;

/* Get macro vars to populate json*/
proc sql noprint;
	SELECT alertid,modifiedTimeStamp,tranwrd(actionableEntityLabel,"'","''") 
	INTO :alert_id,:modifiedTimeStamp,:actionableEntityLabel 
	FROM get_resp.root;
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to get alert info from web service;
   %goto MACRO_END;
%end;

%put NOTE: Processing Alert &alert_id, for entity %superq(actionableEntityLabel) modified at &modifiedTimeStamp;

/* Create json to disposition alert to an existing review */
filename dspalrt "%sysfunc(pathname(work))/disp_alert_req.json";
filename cc_out "%sysfunc(pathname(work))/disp_alert_resp.json";

proc json out=dspalrt pretty;		
	write values 'dispositionId' "crr_open_review";
			write values 'promptForQueue' false;
			write values 'promptForActivationTime' false;
			write values 'promptForDocument' true;
			write values "documentTypeName" "crr_edd_reviews";
			write values 'documentFields';
			write open object;
                        write values 'description' "EDD review auto disposition.";
			write close;
			write values 'promptForRelationship' false;
			write values 'relationshipNames';
			write open array;
			write values "PTY";
			write close;
			write values 'promptForScenarioFired' false;
			write values 'promptForRest' false;
			write values 'restFields';
			write open object;
			write close;
			write values 'modifiedOverride' false;
			write values 'promptForNoteFlag' false;
			write values 'promptForReasonFlag' false;
			write values 'alerts';
			write open array;
			write open object;
			write values 'modifiedTimeStamp' "&modifiedTimeStamp";
			write values 'alertId' "&alert_id";
			write values "actionableEntityType" "PTY";
			write close;
			write close;
			write values "newDocument" false;
			write values "documentId" "&edd_id";
			write values 'dispositionNote' "CDD auto disposition to existing review for %superq(actionableEntityLabel)";
		run;
%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to create json for alert dispositioned to existing review;
   %goto MACRO_END;
%end;

%fdx_ws_http_post_json(url=/svi-alert/alertDecisions/crr_open_review, ws_in_json_fref=dspalrt, _ws_out_json_fref=cc_out);

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to disposition alert to existing review;
   %goto MACRO_END;
%end;
%let disp_err=0;
	data _null_;
		infile cc_out truncover;
		length txt2 $32767;
		input;
		txt2=_infile_;
		txt2=compress(txt2);
		disp_err=index(txt2,'"success":false');
		if disp_err gt 0 then call symput('disp_err',disp_err);
	run;
	%put NOTE: disp_err is &disp_err;
	%if &disp_err gt 0 %then %do;
		%put ERROR: Disposition crr_open_review failed for alert_id &alert_id ;
	%goto MACRO_END;
	%end;
%end; 
/* loop through each alert in disp_to_existing */


%DISP_NEW:
/*get count of alerts to be dispositioned to an existing review*/
proc sql noprint;
select count(*) into: altnewcnt from disp_to_new;
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to get count of alerts dispositioned to new reviews;
   %goto MACRO_END;
%end;
%put NOTE: Count of alerts to be dispositioned to an existing reviews altnewcnt=&altnewcnt;

%if &altnewcnt eq 0 %then %do;
%put NOTE: No new alerts need to be dispostioned to a new review;
%goto MACRO_END;
%end;

/*get numbered macro variables to loop through*/
proc sql noprint;
select alert_id,employee_ind into :alert_id1-:alert_id%trim(&altnewcnt)
,:employee_ind1-:employee_ind%trim(&altnewcnt)
from disp_to_new;
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: failed to get macro vars of alerts dispositioned to new reviews.;
   %goto MACRO_END;
%end;

/*Loop through each alert in disp_to_new and disposition to existing review*/
%do i=1 %to &altnewcnt;
%let alert_id=&&alert_id&i;
%let alert_url=/svi-alert/alerts/&alert_id;

/*get current modifiedTimeStamp from alert service*/
%fdx_ws_http_get_json(url=&alert_url, _ws_http_code=http_ret_code);
libname get_resp json fileref=ws_out;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: failed to get info of alert dispositioned to new review;
   %goto MACRO_END;
%end;

/*get macro vars to populate json*/
proc sql noprint;
	select alertid,modifiedTimeStamp,tranwrd(actionableEntityLabel,"'","''")
	into :alert_id,:modifiedTimeStamp,:actionableEntityLabel trimmed
	from get_resp.root;
quit;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: failed to get info of alert dispositioned to new review into macro vars;
   %goto MACRO_END;
%end;
%put NOTE: DEBUG> processing Alert &alert_id, for entity %superq(actionableEntityLabel) modified at &modifiedTimeStamp;

/*create json to disposition alert to an existing review*/
filename dspalrt "%sysfunc(pathname(work))/disp_alert_req.json";
*filename cc_out "%sysfunc(pathname(work))/disp_alert_resp.json";
filename cc_out "/opt/project/payload/disp_alert_resp.json";

		proc json out=dspalrt pretty;
			write values 'dispositionId' "crr_open_review";
			write values 'promptForQueue' false;
			write values 'promptForActivationTime' false;
			write values 'promptForDocument' true;
			write values "documentTypeName" "crr_edd_reviews";
			write values 'documentFields';
			write open object;
			/*write values "employee_ind" "&&employee_ind&i";*/
                        write values 'description' "&rv_desc";
			write close;
			write values 'promptForRelationship' false;
			write values 'relationshipNames';
			write open array;
			write values "&rv_rel";
			write close;
			write values 'promptForScenarioFired' false;
			write values 'promptForRest' false;
			write values 'restFields';
			write open object;
			write close;
			write values 'modifiedOverride' false;
			write values 'promptForNoteFlag' false;
			write values 'promptForReasonFlag' false;
			write values 'alerts';
			write open array;
			write open object;
			write values 'modifiedTimeStamp' "&modifiedTimeStamp";
			write values 'alertId' "&alert_id";
			write values "actionableEntityType" "PTY";
			write close;
			write close;
			write values "newDocument" true;
			write values 'dispositionNote' "CDD auto disposition to new review for %superq(actionableEntityLabel) ";
		run;

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to create json of alerts dispositioned to new reviews.;
   %goto MACRO_END;
%end;

%fdx_ws_http_post_json(url=/svi-alert/alertDecisions/crr_open_review, ws_in_json_fref=dspalrt, _ws_out_json_fref=cc_out);

%fsccheckrc;
%if &bat_abort=Y %then %do;
   %put NOTE: Failed to create alert dispositioned to new reviews.;
   %goto MACRO_END;
%end;
%let disp_err=0;
	data _null_;
		infile cc_out truncover;
		length txt2 $32767;
		input;
		txt2=_infile_;
		txt2=compress(txt2);
		disp_err=index(txt2,'"success":false');
		if disp_err gt 0 then call symput('disp_err',disp_err);
	run;
	%put NOTE: disp_err is &disp_err;
	%if &disp_err gt 0 %then %do;
		%put ERROR: Disposition crr_open_review failed for alert_idi: &alert_id ;
	%goto MACRO_END;
	%end;
%end; /*loop through each alert in disp_to_new*/

%MACRO_END:

/*
%if &bat_abort=Y or &syscc=4 %then
			%do;
				%fscprocess(processAction=COMPLETE, processStatus=ERROR, jobId=&jobId, 
					processId=&pid);
			%end;

		%if &bat_abort=N %then
			%do;
				%fscprocessMetric(processId=&pid, metricName=DOEP_DISP_NEW, 
					metricDesc=Watch List Alert Dispostion Alert to New Case, metricValue=&altnewcnt);
				%fscprocessMetric(processId=&pid, metricName=DOEP_DISP_EXISTING, 
					metricDesc=Watch List Alert Dispostion Alert to Existing Case, metricValue=&altextcnt);
				%fscprocess(processAction=COMPLETE, processStatus=SUCCESS, jobId=&jobId, 
					processId=&pid);
			%end;
		%put NOTE: {END: psd_adhoc_alert_close};
*/
%mend;
/* Would need to assign an actual Job ID in FSC_JOB (JobID=) */
