/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Pete Ferrera (pete.ferrera@sas.com)
/ PURPOSE      : 
/ DESCRIPTION  : 
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ alert_id            doc type (table name in fdhdata)
/ t_disposition       unique identifier for the doc type
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_move_alert_queue(alert_id=,
/                                  t_disposition=);

/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_move_alert_queue(alert_id=,t_disposition=);

%let alert_url=/svi-alert/alerts/&alert_id;
%usps_vi_ws_http_get_json(url=&alert_url, _ws_http_code=http_ret_code);
libname get_resp json fileref=ws_out;

/*get macro vars to populate json*/
proc sql;
	select alertid,modifiedTimeStamp,actionableEntityType,alertDispositionId
	into :alert_id,:modifiedTimeStamp,:actionableEntityType,:s_disposition
	from get_resp.root;
quit;

proc sql noprint;
select alert_disposition_nm
into: alert_disposition_nm
from alerts.tdc_alert_disposition
where alert_disposition_id="&t_disposition."
;quit;

/*CREATE JSON PAYLOAD*/
filename dsp_alt "%sysfunc(pathname(work))/disp_alert_req.json";
filename cc_out "%sysfunc(pathname(work))/disp_alert_resp.json";

proc json out=dsp_alt pretty nosastags;
	write values 'dispositionId' "&t_disposition";
	write values 'promptForQueue' false;
	write values 'promptForActivationTime' false;
	write values 'promptForDocument' false;
	write values 'documentFields';
	write open object;
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
	write values "actionableEntityType" "&s_disposition";
	write close;
	write close;
	write values "newDocument" false;
	write values 'dispositionNote' "Batch operation to move alert to target queue";
run;

%let disp_url=svi-alert/alertDecisions/&t_disposition.;
%usps_vi_ws_http_post_json(url=&disp_url, ws_in_json_fref=dsp_alt,_ws_out_json_fref=cc_out);

%mend fdx_move_alert_queue;


%fdx_move_alert_queue(alert_id=%str(5d5f3746-2592-414f-9b72-b35332bc6d00),t_disposition=mv_high_queue_disp);
