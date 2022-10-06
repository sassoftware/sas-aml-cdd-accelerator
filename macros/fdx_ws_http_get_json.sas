/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Execute Web Service GET request to retrieve current document
/ DESCRIPTION  : This macro executes a web service GET request for the supplied url.
/                The resulting json is written to the _ws_out_json parameter. The http code is written to the
/                _ws_http_code parameter.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ url                 document name
/ _ws_out_json        macro variable storing response
/ _ws_http_code       macro variable storing response code
/ _error_ind          indicator to print helpful debug info to log
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_ws_http_get_json(url=,
/                                  _ws_out_json=,
/                                  _ws_http_code=,
/                                  _error_ind=);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_ws_http_get_json(url=, _ws_out_json=, _ws_out_json_fref=, _ws_http_code=, error_ind=);
options nosyntaxcheck;
%if %length(&error_ind) = 0 %then %let error_ind=Y;
%if %length(&_ws_out_json) = 0 %then %let _ws_out_json = tmp_ws_out_json;
%if %length(&_ws_http_code) = 0 %then %let _ws_http_code = tmp_ws_http_code;

%let &_ws_out_json=;
%let &_ws_http_code=0;

/*%global WS_TOKEN;*/
/*%fdx_ws_get_oauth_token();*/

%if %length(&_ws_out_json_fref) = 0 %then %do;
  filename ws_out "%sysfunc(pathname(work))/ws_out.txt";
  %let _ws_out_json_fref = ws_out;
%end;

%let SYS_PROCHTTP_STATUS_CODE=0;
proc http 
  url="&WS_BASE_URL/%superq(url)"
  method="get"
  ct="application/json;charset=UTF-8"
  clear_cookies
  oauth_bearer=&access_token.
  out=&_ws_out_json_fref;
  
run; 
%if %symexist(SYS_PROCHTTP_STATUS_CODE) %then %do;
%put NOTE: SYS_PROCHTTP_STATUS_CODE is &SYS_PROCHTTP_STATUS_CODE  SYSCC is &SYSCC;
/*if SYS_PROCHTTP_STATUS_CODE exists then we don't want SYSCC considered for retry processing, set SYSCC=0*/
%let SYSCC=0;
%end;
%else %do;
%let SYS_PROCHTTP_STATUS_CODE=0;
%put NOTE: SYS_PROCHTTP_STATUS_CODE is does not exist  SYSCC is &SYSCC;
%end;

%if &SYS_PROCHTTP_STATUS_CODE gt 499 or &SYS_PROCHTTP_STATUS_CODE eq 403 or &SYSCC gt 4 %then %do;
		%if %sysfunc(getoption(obs))=0 %then %do;
		  options obs=max replace NoSyntaxCheck;
		%end;
		/*reset status codes*/
		%put NOTE: Previous ERROR may be intermittent only. Retrying request &WS_BASE_URL/%superq(url);
		%let SYS_PROCHTTP_STATUS_CODE=0;
		%let SYSCC=0;
		proc http 
		  url="&WS_BASE_URL/%superq(url)"
		  method="get"
		  ct="application/json;charset=UTF-8"
		  clear_cookies
		  oauth_bearer=&access_token.
		  out=&_ws_out_json_fref;
		  
		run; 
%end;

%let &_ws_http_code=&SYS_PROCHTTP_STATUS_CODE;

%put DEBUG: ws_out %sysfunc(pathname(ws_out));;
data _null_;
  infile &_ws_out_json_fref lrecl=32767;
  input;
  put "DEBUG: > " _infile_;
  call symputx("&_ws_out_json",_infile_,'G');
  call symputx("&_ws_http_code","&SYS_PROCHTTP_STATUS_CODE",'G');
run;

%if not (&SYS_PROCHTTP_STATUS_CODE eq 200 or &SYS_PROCHTTP_STATUS_CODE eq 201) %then %do;
  %if &error_ind=Y %then %do;
	%put ERROR: HTTP Status Code=&SYS_PROCHTTP_STATUS_CODE: &SYS_PROCHTTP_STATUS_PHRASE;
  %end;
  %else %do;  
	%put NOTE: HTTP Status Code=&SYS_PROCHTTP_STATUS_CODE: &SYS_PROCHTTP_STATUS_PHRASE;
  %end;
  %let SYSCC=9999;
  %return;
%end;

options syntaxcheck;
%mend;
