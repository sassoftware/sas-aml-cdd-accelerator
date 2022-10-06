/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PURPOSE      : 
/ DESCRIPTION  : Check for an abnormal return code and act if one found
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fscheckrc();
/--------------------------------------------------------------------------------------------------------------------*/

%macro fsccheckrc;

   %put NOTE: {START: fsccheckrc};
   
   %local bat_errMsg bat_err;
   %global bat_abort globalErr;
   %let bat_errmsg=;
   %let bat_err=0;
   %let bat_abort=N;
   %let globalErr=&SYSERRORTEXT;

   %if &syserr eq 3 or &syserr gt 4 %then
   %do;

       %let bat_errMsg=%sysfunc(sysmsg());
       
       %if %length(&bat_errMsg) le 0 %then
           %let bat_errMsg=&bat_abort syserr=&syserr;
       %let bat_err=&syserr;

   %end;

   %if %symexist(sysrc) %then
   %do;/* from local sql */
   
     %if (&bat_err eq 4 or &bat_err lt 3) %then
        %if &sysrc gt 4 %then
        %do;
           %let bat_err=&sysrc;
           %let bat_errMsg=&sysmsg;
        %end;
   %end;

   %if %symexist(sqlrc) %then
   %do;/* from local sql */
   
	  %if (&bat_err eq 4 or &bat_err lt 3) %then
		  %if &sqlrc gt 4 %then
        %do;
			  %let bat_err=&sqlrc;
           %let bat_errMsg=&sqlmsg;
        %end;
   %end;

   %if %symexist(sysdbrc) %then
   %do;/* from db update */
   
     %if (&bat_err eq 4 or &bat_err lt 3) %then
/*	 NOTE: 100 is a valid code */
        %if &sysdbrc gt 4 and &sysdbrc ne 100 %then
        %do;
           %let bat_err=&sysdbrc;
           %let bat_errMsg=&sysdbmsg;
        %end;
   %end;
   %if %symexist(sqlxrc) %then
   %do; /* from sql passthrough */
   
     %if (&bat_err eq 4 or &bat_err lt 3) %then
        %if &sqlxrc gt 4 %then
        %do;
           %let bat_err=&sqlxrc;
           %let bat_errMsg=&sqlxmsg;
        %end;
   %end;
   
   %if &bat_err eq 3 or &bat_err gt 4 %then
   %do;
     
     %PUT ERROR: Aborting batch job.;
     %put '    ' &bat_errMsg;
     %let bat_abort=Y;
   %end;
   %else
   %if &sysrc ne 0 %then
   %do;

      %let bat_errMsg=%sysfunc(sysmsg());
       
      %if %length(&bat_errMsg) le 0 %then
           %let bat_errMsg=&bat_abort sysrc=&sysrc;
      %let bat_err=&sysrc;
       
      %PUT ERROR: Aborting batch job.;
      %put NOTE:'    ' &bat_errMsg;
      %let bat_abort=Y;
   %end;

   %if %symexist(syswarningtext) and &syserr eq 4 %then %do;
      %if %sysfunc(find(compress(&syswarningtext,','),rejected)) gt 0 %then %do;
         %let bat_errMsg=&syswarningtext;
         %PUT ERROR: Aborting batch job.;
         %put NOTE:'    ' &bat_errMsg;
         %let bat_abort=Y;
      %end;
   %end;



   %put NOTE: {END: fsccheckrc};   
%mend ;
