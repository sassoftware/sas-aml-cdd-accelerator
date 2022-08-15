/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PURPOSE      : Sets runasofdate
/ DESCRIPTION  : Reads FSC_JOB_CALENDAR and sets aml_daily, aml_weekly, aml_monthly runasofdate
/                Loads num_date and date_num formats
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fdx_get_runasofdate;
/--------------------------------------------------------------------------------------------------------------------*/

/*
    Macro: fdx_get_runasofdate;
      Reads FSC_JOB_CALENDAR and sets 
         aml_daily, aml_weekly, aml_monthly runasofdate
      Loads num_date and date_num formats         
*/
%macro fdx_get_runasofdate;
  
%global aml_daily aml_monthly aml_weekly;
%global rundate runasofdate;

proc sql threads noprint;
  select calendar_date, daily_rundate_ind, weekly_rundate_ind, monthly_rundate_ind
  into :rundate,
       :aml_daily, :aml_weekly, :aml_monthly
  from &core_db..fsc_job_calendar
  where calendar_date = (select min(calendar_date)
                from &core_db..fsc_job_calendar
                where rundate_ind eq 'Y' and status_ind ne 'Y');
quit;
%fcf_chkrc;
 %if &bat_abort=Y %then %do;
   %put NOTE: STEP: &step;
   %goto exit;
 %end;


data _null_;
  runasofdate = put(datepart("&rundate."dt),yymmddn8.);
  call symput('runasofdate',runasofdate);
run;  
%fcf_chkrc;
 %if &bat_abort=Y %then %do;
   %put NOTE: STEP: &step;
   %goto exit;
 %end;

%exit:
%mend;

/* %fdx_get_runasofdate; */
/* %put &runasofdate &rundate &aml_daily &aml_weekly &aml_monthly; */
