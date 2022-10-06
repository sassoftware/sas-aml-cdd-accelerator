/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PURPOSE      : Create password protected dataset
/ DESCRIPTION  : This macro implements several methods for SAS wallet.
/                SAS wallet is password protected dataset key/value pairs.
/
/ SAS WALLET SETUP INSTRUCTIONS:
/                1. Create hidden folder for the wallet -> mkdir ~/.wlt
/                2. Run wallet generation method -> %sas_wallet(create)
/                3. Protect the wallet -> chmod 600 ~/.wlt/wlt_kv.sas7bdat
/                4. Put values into wallet -> %sas_wallet(put,user,u123123)
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:    %sas_wallet(create);
/             %sas_wallet(put,WS_USER,johndoe);
/             %sas_wallet(put,WS_PASSWORD,passpass);
/             %sas_wallet(get_val,WS_USER);
/             %sas_wallet(get_all);
/             %sas_wallet(clear);
/--------------------------------------------------------------------------------------------------------------------*/

%macro sas_wallet(action,key,val);

/* grab user name */
%let myuser=%sysget(USER);
%put &=myuser;

%if &myuser eq 0 %then %do;
	%put "ERROR: The user is not being defined.";
	%goto MACRO_END;
%end;

options DLCREATEDIR ;
/* generate key-value store key */ 
 data _null_;
  call symput('wlt_key',substr(put(symget('myuser'),$base64x64.),1,8));
 run;
 libname myhome "/home/&myuser/.wlt";

 %if &action. eq create %then %do;
/* create key protected key-value store dataset */ 
  data myhome.wlt_kv(pw="&wlt_key.");
   length key $32 val $1024;
   stop;
  run;
 %end;

 %if &action. eq drop %then %do;
/* drop key-value store dataset */ 
  proc sql noprint;
   drop table myhome.wlt_kv(pw="&wlt_key.");
  quit;
 %end;

 %if &action. eq put %then %do;
/* place key-value pair into the dataset */ 
  proc sql noprint;
   delete from myhome.wlt_kv(pw="&wlt_key.")
   where key=put("&key.",$base64x64.)
  ;
   insert into myhome.wlt_kv(pw="&wlt_key.")
   set key=put("&key.",$base64x64.),
       val=put("&val.",$base64x64.)
  ;
  quit;
 %end;

 %if &action. eq get_val %then %do;
/* get specified key-val pair into global macro variable */
  data _null_;
   set myhome.wlt_kv(pw="&wlt_key.");
   if key eq put("&key.",$base64x64.);
   call symputx(input(key,$base64x64.),input(val,$base64x64.),G);
  run;
 %end;

 %if &action. eq get_all %then %do;
/* get all key-val pairs into global macro variables */ 
  data _null_;
   set myhome.wlt_kv(pw="&wlt_key.");
   call symputx(input(key,$base64x64.),input(val,$base64x64.),G);
  run;
 %end;

 %if &action. eq clear %then %do;
/* clear global macro variables with values of key-val pairs */ 
  data _null_;
   set myhome.wlt_kv(pw="&wlt_key.");
   call symputx(input(key,$base64x64.),'',G);
  run;
 %end;

%MACRO_END:
%mend sas_wallet;

