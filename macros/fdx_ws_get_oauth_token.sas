/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PURPOSE      : Get the bearer token for Web Service requests
/ DESCRIPTION  : This macro retrieves and stores the bearer token for WS requests in a global variable WS_TOKEN.
/                This macro should not be called directly. It we be invoked by fdx_ws_http_post_json.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ debug               indicator for printing additional info to log
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_ws_get_oauth_token(debug=N);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_ws_get_oauth_token(debug=N);
%let debug=Y;
/*Keep current datetime every time WS_TOKEN is set and reset every hour for long running programs*/

data _null_;
length ws_token $32760;
dttm=datetime();
if "&WS_TOKEN_DTTM" eq "" then old_dttm=dttm;
else old_dttm="&WS_TOKEN_DTTM"dt;
ws_token="&WS_TOKEN";
hours = intck('hour', old_dttm, dttm, 'continuous');
if strip(ws_token) eq '' or hours gt 7 then do;
	dttm_str=put(dttm,datetime20.);
	call symputx("WS_TOKEN_DTTM",dttm_str,g);
	call symputx("WS_TOKEN",'',g);
	  %if &debug eq Y %then %do;
		put "NOTE: Resetting WS_TOKEN info ***" _all_; 
	  %end;
end;
  %if &debug eq Y %then %do;
   put "NOTE: token info ***" _all_; 
  %end;
run;

%if &debug=Y %then %do;
%put NOTE: WS_TOKEN_DTTM is &WS_TOKEN_DTTM;
%put NOTE: WS_TOKEN is &WS_TOKEN;
%end;

%if %length(&WS_TOKEN) gt 0 %then %goto OAUTH_END;
filename l_hdrs "%sysfunc(pathname(work))/l_hdrs.txt";
filename l_resp "%sysfunc(pathname(work))/l_resp.txt";
filename l_hdrs_o "%sysfunc(pathname(work))/l_hdrs_o.txt";

/* Grab the User Token */
data _null_;
  file l_hdrs;
  put "Accept: application/json";
  USER_TOKEN="Authorization: Basic " !! put( compress( "sas.ec" || ":"),$base64x32767.);
	put USER_TOKEN; 
run;

%if &debug eq Y %then %do;
%put DEBUG: l_hdrs %sysfunc(pathname(l_hdrs));;
data _null_;
  infile l_hdrs;
  input;
  put "DEBUG: > " _infile_;
run;
%end;

%sas_wallet(get_all);
/* Using Token, get authorization */
proc http
  in="grant_type=password%str(&)username=&WS_USER%str(&)password=&WS_PASSWORD."
  webusername='sas.ec'
  headerin=l_hdrs
  out=l_resp
  headerout=l_hdrs_o
  url="&WS_BASE_URL/SASLogon/oauth/token"
  method='post'
  HEADEROUT_OVERWRITE;
run;
%sas_wallet(clear);

  %if &debug eq Y %then %do;
%put DEBUG: l_hdrs_o %sysfunc(pathname(l_hdrs_o));;
data _null_;
  infile l_hdrs_o;
  input;
  put "DEBUG: > " _infile_;
run;

%put DEBUG: l_resp %sysfunc(pathname(l_resp));;
data _null_;
  infile l_resp;
  input;
  put "DEBUG: > " _infile_;
run;
%end;

options noquotelenmax;  
/*Parse Token and create alert insert request headers*/
data _null_;
   infile l_resp ;
   input;
   token = "Bearer " !! dequote( scan( scan(_infile_, 1, ','), 2, ':'));
   call symput('WS_TOKEN', trim(left(token)));
   call symputx('access_token', '"' || strip(substr(token,8)) || '"');
run;

/* set auth token environment variable */
 options set=SAS_VIYA_TOKEN=&access_token.;

%OAUTH_END:
%mend;
