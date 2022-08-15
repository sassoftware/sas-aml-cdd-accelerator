/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Execute Web Service GET request to retrieve current document
/ DESCRIPTION  : This macro executes a web service GET request for the supplied document type and document id.
/                The resulting json is written to the _ws_out_json parameter. THe http code is written to the
/                _ws_http_code parameter.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ object_type         document name
/ object_id           primary key of object_type
/ _ws_out_json        macro variable storing response
/ _ws_http_code       macro variable storing response code
/ debug               indicator to print helpful debug info to log
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_ws_get_doc_json(object_type=tm_cases,
/                                 object_id=202000001,
/                                 _ws_out_json=json_out,
/                                 _ws_http_code=resp_code,
/                                 debug=N);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_ws_get_doc_json(object_type=, object_id=, _ws_out_json=, _ws_http_code=,debug=N);

%if %length(&_ws_out_json) = 0 %then %let _ws_out_json = tmp_ws_out_json;
%if %length(&_ws_http_code) = 0 %then %let _ws_http_code = tmp_ws_http_code;

%let &_ws_out_json=;
%let &_ws_http_code=0;

%global WS_TOKEN;
%fdx_ws_get_oauth_token();

filename ws_out "%sysfunc(pathname(work))/ws_out.txt";

%let SYS_PROCHTTP_STATUS_CODE=0;
proc http 
  url="&WS_BASE_URL/svi-datahub/documents/&object_type./&object_id.?depth=FULL"
  method="get"
  ct="application/json;charset=UTF-8"
  oauth_bearer=&access_token.
  clear_cookies
  out=ws_out;
run; quit;

%let &_ws_http_code=&SYS_PROCHTTP_STATUS_CODE;

%if &debug eq Y %then %do;
%put DEBUG: ws_out %sysfunc(pathname(ws_out));;
%end;
data _null_;
  infile ws_out lrecl=32767;
  input;
%if &debug eq Y %then %do;	
  put "DEBUG: > " _infile_;
%end;
  call symput("&_ws_out_json",_infile_);
run;

%if not (&SYS_PROCHTTP_STATUS_CODE eq 200 or &SYS_PROCHTTP_STATUS_CODE eq 201) %then %do;
  %put ERROR: HTTP Status Code=&SYS_PROCHTTP_STATUS_CODE: &SYS_PROCHTTP_STATUS_PHRASE;
  %let SYSCC=9999;
  %return;
%end;

%mend;
