/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Pete Ferrera (pete.ferrera@sas.com)
/ PURPOSE      : Add comment to SAS VI object
/ DESCRIPTION  : Adds comment to SAS VI object using a PROC JSON and %fdx_ws_http_post_json.sas macro
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ object_id           id of the object to add comment
/ object_type         type of the object for &object_id
/ message             message to post in the comment
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fdx_add_comment(object_id=20200711,
/                           object_type=tm_cases,
/                           message=%str(<p>Testing</p><p>Comment</p><p>with</p><p>Linefeed</p>));
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_add_comment(object_id=,object_type=,message=);
%if %length(&object_id) eq 0 %then %do;
  %put ERROR: fdx_add_comment - object_id parameter is required;
  %goto ADD_END;
%end;
%if %length(&object_type) eq 0 %then %do;
  %put ERROR: fdx_add_comment - object_type parameter is required;
  %goto ADD_END;
%end;
%if %length(%superq(message)) eq 0 %then %do;
  %put ERROR: fdx_add_comment - message parameter is required;
  %goto ADD_END;
%end;

filename cmt_req "%sysfunc(pathname(work))/comment_&object_type._&object_id..json";
filename ws_out "%sysfunc(pathname(work))/resp_comment_&object_type._&object_id..txt";
data a;
message="%superq(message)";
call symput("message",strip(message));
run;


proc json out=cmt_req pretty nosastags;
	write values "category" "";
	write values "detail" "%superq(message)";
run;


%global ws_http_code;
%let ws_http_code=0;
%fdx_ws_http_post_json(
      url=/svi-datahub/documents/&object_type./&object_id./comments, 
      ws_in_json_fref=cmt_req,
      _ws_out_json_fref=ws_out,
      _ws_http_code=ws_http_code
    );
 
    %put NOTE: SYS_PROCHTTP_STATUS_CODE is &SYS_PROCHTTP_STATUS_CODE;
    %if &SYS_PROCHTTP_STATUS_CODE ne 201 and &SYS_PROCHTTP_STATUS_CODE ne 200 %then %do;
      %put ERROR: Failed to execute POST request to update comment;
    %end;

%ADD_END:
%mend;
