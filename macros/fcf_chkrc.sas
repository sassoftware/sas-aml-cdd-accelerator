/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PURPOSE      : Check Return Code
/ DESCRIPTION  : Check for an abnormal return code
/                Outputs - Global macro variable bat_abort set to Y or N
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fcf_chkrc;
/--------------------------------------------------------------------------------------------------------------------*/

%macro fcf_chkrc;

   %put NOTE: {START: fcf_chkrc};
   
   %local bat_err;
   %global bat_abort;
   %global bat_errMsg;
   %let bat_errmsg=;
   %let bat_err=0;
   %let bat_abort=N;

   %if &syserr eq 3 or &syserr gt 4 %then %do;
     %put SYSERR: &syserr;
     %let bat_errMsg=%sysfunc(sysmsg());
     %if %length(&bat_errMsg) le 0 %then
       %let bat_errMsg=&bat_abort syserr=&syserr;
     %let bat_err=&syserr;
   %end;

   %if %symexist(sysrc) %then %do;  /* from local sql */
     %if (&bat_err eq 4 or &bat_err lt 3) %then %do;
       %if &sysrc gt 4 %then %do;
         %let bat_err=&sysrc;
         %let bat_errMsg=%sysfunc(sysmsg());
       %end;
     %end;
     %if &sysrc gt 4 %then %put ERROR: SYSRC: &sysrc SYSMSG: %sysfunc(sysmsg());
   %end;

   %if %symexist(sqlrc) %then %do;  /* from local sql */
	 %if (&bat_err eq 4 or &bat_err lt 3) %then %do;
	   %if &sqlrc gt 4 %then %do;
         %let bat_err=&sqlrc;
         %let bat_errMsg=%superq(syserrortext);
       %end;
     %end;
     %if &sqlrc gt 4 %then %put ERROR: SQLRC: &sqlrc SYSERRORTEXT: %superq(syserrortext);
   %end;

   %if %symexist(sysdbrc) %then %do;  /* from db update */
     %if (&bat_err eq 4 or &bat_err lt 3) %then %do;
       %if &sysdbrc gt 4 %then %do;
         %let bat_err=&sysdbrc;
         %let bat_errMsg=&sysdbmsg;
       %end;
     %end;
     %if &sysdbrc gt 4 %then %put ERROR: SYSDBRC: &sysdbrc SYSDBMSG: &sysdbmsg;
   %end;
   
   %if %symexist(sqlxrc) %then %do;  /* from sql passthrough */
     %if (&bat_err eq 4 or &bat_err lt 3) %then %do;
       %if &sqlxrc gt 4 %then %do;
         %let bat_err=&sqlxrc;
         %let bat_errMsg=&sqlxmsg;
       %end;
     %end;
     %if &sqlxrc gt 4 %then %put ERROR: SQLXRC: &sqlxrc SQLXMSG: &sqlxmsg;
   %end;
   
   %if &bat_err eq 3 or &bat_err gt 4 %then %do;
     %put ERROR: Aborting job.;
     %put &bat_errMsg;
     %let bat_abort=Y;
   %end;
   %else %if &sysrc ne 0 %then %do;
     %let bat_errMsg=%sysfunc(sysmsg());
       
     %if %length(&bat_errMsg) le 0 %then
       %let bat_errMsg=&bat_abort sysrc=&sysrc;
     %let bat_err=&sysrc;
       
     %put ERROR: Aborting job.;
     %put NOTE: &bat_errMsg;
     %let bat_abort=Y;
   %end;

   %put NOTE: {END: fcf_chkrc};

%mend fcf_chkrc;
