/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Execute Web Service PUT request to update a document
/ DESCRIPTION  : This macro executes a web service PUT request for the supplied object type, object id, and JSON 
/                macro variable ws_in_json.
/                The resulting json is written to the _ws_out_json parameter. THe http code is written to the
/                _ws_http_code parameter
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ object_type         document name
/ object_id           primary key of object_type
/ ws_in_json          macro variable storing JSON payload
/ ws_in_json_fref     fileref storing JSON payload
/ _ws_out_json        macro variable storing response
/ _ws_out_json_fref   fileref for JSON response
/ _ws_http_code       macro variable storing response code
/ debug               indicator to print helpful debug info to log
/ error_ind           determines whether to print helpful info to log
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_ws_put_doc_json(object_type=,
/                                 object_id=,
/                                 ws_in_json=,
/                                 ws_in_json_fref=,
/                                 _ws_out_json=,
/                                 _ws_out_json_fref=,
/                                 _ws_http_code=,
/                                 debug=N,
/                                 error_ind=N);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_ws_put_doc_json(object_type=, object_id=, ws_in_json=, ws_in_json_fref=, _ws_out_json=, _ws_out_json_fref=, _ws_http_code=,debug=N,error_ind=N);

%if %length(&_ws_out_json) = 0 %then %let _ws_out_json = tmp_ws_out_json;
%if %length(&_ws_http_code) = 0 %then %let _ws_http_code = tmp_ws_http_code;

%let &_ws_out_json=;
%let &_ws_http_code=0;

/*%global WS_TOKEN;*/
/*%fdx_ws_get_oauth_token();*/

%if %length(&ws_in_json_fref) = 0 %then %do;
  filename ws_in "%sysfunc(pathname(work))/ws_in.txt";

  data _null_;
    file ws_in;
    length ws_in_json $32767;
    ws_in_json = symget("&ws_in_json");
    if ws_in_json ^= '' then do;
      put ws_in_json;
    end;
    else do;
      put '';
    end;
  run;

  %let ws_in_json_fref = ws_in;
%end;

%if %length(&_ws_out_json_fref) = 0 %then %do;
  filename ws_out "%sysfunc(pathname(work))/ws_out.txt";
  %let _ws_out_json_fref = ws_out;
%end;


%if &debug eq Y %then %do;
%put DEBUG: ws_in %sysfunc(pathname(&ws_in_json_fref));
data _null_;
  infile &ws_in_json_fref;
  input;
  put "DEBUG: > " _infile_;
run;
%end;
%let SYSCC=0;
%let SYS_PROCHTTP_STATUS_CODE=0;
proc http 
  url="&WS_BASE_URL/svi-datahub/documents/&object_type./&object_id."
  method="put"
  ct="application/json;charset=UTF-8"
  clear_cookies
  oauth_bearer=&access_token.
  in=&ws_in_json_fref
  out=&_ws_out_json_fref;
  
run; 
%put NOTE: SYS_PROCHTTP_STATUS_CODE is &SYS_PROCHTTP_STATUS_CODE : SYSCC is &SYSCC;

%if &SYS_PROCHTTP_STATUS_CODE gt 201 or &SYSCC gt 4 %then %do;
		%if %sysfunc(getoption(obs))=0 %then %do;
		  options obs=max replace NoSyntaxCheck;
		%end;
		%let SYS_PROCHTTP_STATUS_CODE=0;
		proc http 
		  url="&WS_BASE_URL/svi-datahub/documents/&object_type./&object_id."
		  method="put"
		  ct="application/json;charset=UTF-8"
		  clear_cookies
		  oauth_bearer=&access_token.
		  in=&ws_in_json_fref
		  out=&_ws_out_json_fref;

		run; 
%end;
%let &_ws_http_code=&SYS_PROCHTTP_STATUS_CODE;

%if &debug eq Y %then %do;
%put DEBUG: ws_out %sysfunc(pathname(ws_out));;
data _null_;
  infile &_ws_out_json_fref lrecl=32767;
  input;
  put "DEBUG: > " _infile_;
  call symput("&_ws_out_json",_infile_);
run;
%end;

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

%mend;
