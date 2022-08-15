/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com) & Pete Ferrera (pete.ferrera@sas.com)
/ PURPOSE      : Execute Web Service POST request with JSON payload
/ DESCRIPTION  : This macro executes a web service POST request again the WS_BASE_URL. The parameter url allows
/                to append to the WS_BASE_URL. The JSON request payload is passed in via the parameter
/                ws_in_json.
/                On success the macro returns the JSON response in the macro variable specified by _ws_out_json
/                and the HTTP Status code in the marco variable specified by _ws_http_code.
/                On failure (ws_http_code not in 200,201) SYSCC will also be set to 9999.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ url                 request URL
/ ws_in_json          macro variable storing JSON payload
/ ws_in_json_fref     fileref storing JSON payload
/ _ws_out_json        macro variable storing JSON response
/ _ws_out_json_fref   fileref storing JSON response
/ error_ind           determines whether to print a NOTE or ERROR to log if call fails
/ content_disp        content disposition
/ debug_print         determines whether to print helpful info to log
/ use_content_type    additional content type parameter for bulk option
/ bulk                indicator to use bulk load
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_ws_http_post_json(url=,
/                                   ws_in_json=,
/                                   ws_in_json_fref=,
/                                   _ws_out_json=,
/                                   _ws_out_json_fref=,
/                                   _ws_http_code=,
/                                   error_ind=,
/                                   content_disp=,
/                                   debug_print=Y,
/                                   use_content_type=Y,
/                                   bulk=N);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_ws_http_post_json(url=, ws_in_json=, ws_in_json_fref=, _ws_out_json=, _ws_out_json_fref=, _ws_http_code=, error_ind=, content_disp=,debug_print=Y,use_content_type=Y,bulk=N);

%if %length(&error_ind) = 0 %then %let error_ind=Y;
%if %length(&_ws_out_json) = 0 %then %let _ws_out_json = tmp_ws_out_json;
%if %length(&_ws_http_code) = 0 %then %let _ws_http_code = tmp_ws_http_code;

%let &_ws_out_json=;
%let &_ws_http_code=0;

%global WS_TOKEN;
%fdx_ws_get_oauth_token();

%if %length(&ws_in_json_fref) = 0 %then %do;
  filename ws_in "%sysfunc(pathname(work))/ws_in.txt";

  data _null_;
    file ws_in;
    length ws_in_json $32767;
    ws_in_json = symget("ws_in_json");
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

%if &debug_print eq Y %then %do;
%put DEBUG: ws_in %sysfunc(pathname(&ws_in_json_fref));
data _null_;
  infile &ws_in_json_fref;
  input;
  put "DEBUG: > " _infile_;
run;
%end;

%let SYS_PROCHTTP_STATUS_CODE=0;
proc http 
     url="&WS_BASE_URL./%superq(url)"
     method="post"
	 %if &bulk eq Y %then %do;
	 ct="application/vnd.sas.collection+json"
	 %end;
	 %else %do;
     ct="application/json"
	 %end;
	 oauth_bearer=&access_token.
     in=&ws_in_json_fref 
     out=&_ws_out_json_fref  
   clear_cookies
   ;
     HEADERS "Accept"="application/json, text/plain, */*, application/vnd.sas.collection+json"
/*             "Authorization"="&WS_TOKEN"*/
	   %if &use_content_type=Y %then %do;
             "Content-Type"= "application/json"
	   %end;
	   %if &bulk eq Y %then %do;
			"Content-Type"="application/vnd.sas.collection+json"
	   %end; /*end if bulk eq Y*/
       %if %length(&content_disp.) > 0 %then %do;
       "Content-Disposition"="&content_disp.";
       %end;
       %else %do;
       ;
       %end;
	  
run; 
%if not %symexist(SYS_PROCHTTP_STATUS_CODE) %then %let SYS_PROCHTTP_STATUS_CODE=0;
%put NOTE: SYS_PROCHTTP_STATUS_CODE is &SYS_PROCHTTP_STATUS_CODE : SYSCC is &SYSCC;
%if &SYS_PROCHTTP_STATUS_CODE gt 201 or &SYSCC eq 3000 %then %do;
		%if %sysfunc(getoption(obs))=0 %then %do;
		  options obs=max replace NoSyntaxCheck;
		%end;
		%let SYS_PROCHTTP_STATUS_CODE=0;
		proc http 
     url="&WS_BASE_URL./%superq(url)"
     method="post"
     ct="application/json"
	 oauth_bearer=&access_token.
     in=&ws_in_json_fref 
     out=&_ws_out_json_fref  
   clear_cookies
   ;
     HEADERS "Accept"="application/json, text/plain, */*, application/vnd.sas.collection+json"
/*             "Authorization"="&WS_TOKEN"*/
	   %if &use_content_type=Y %then %do;
             "Content-Type"= "application/json"
	   %end;
       %if %length(&content_disp.) > 0 %then %do;
       "Content-Disposition"="&content_disp.";
       %end;
       %else %do;
       ;
       %end;

run; 
	%end;

%let &_ws_http_code=&SYS_PROCHTTP_STATUS_CODE;

%put DEBUG: ws_out %sysfunc(pathname(ws_out));;
data _null_;
  infile &_ws_out_json_fref lrecl=32767;
  input;
  put "DEBUG: > " _infile_;
  call symput("&_ws_out_json",_infile_);
run;

%put DEBUG: SYS_PROCHTTP_STATUS_CODE=&SYS_PROCHTTP_STATUS_CODE;

%if not (&SYS_PROCHTTP_STATUS_CODE eq 200 or &SYS_PROCHTTP_STATUS_CODE eq 201 or &SYS_PROCHTTP_STATUS_CODE eq 206) %then %do;
  %if &error_ind=Y %then %do;
    %put ERROR: HTTP Status Code=&SYS_PROCHTTP_STATUS_CODE: &SYS_PROCHTTP_STATUS_PHRASE;
	%let SYSCC=9999;
  %end;
  %else %do;  
    %put NOTE: HTTP Status Code=&SYS_PROCHTTP_STATUS_CODE: &SYS_PROCHTTP_STATUS_PHRASE;
  %end;
  %return;
%end;

%mend;
