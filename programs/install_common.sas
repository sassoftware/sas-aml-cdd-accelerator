
proc sql;
    delete from core.fsc_date_dim;
    delete from core.fsc_time_dim;
    delete from core.fsc_month_dim;	
    delete from core.fsc_job_calendar;
quit;

/* CALENDAR_START_DATE */
 * Determines the beginning calendar date to be used when creating
 * FSC_DATE_DIM, FSC_MONTH_DIM, and FSC_JOB_CALENDAR tables.;

 * NOTE 1: CALENDAR_START_DATE be formatted as YYYYMMDD.;
 * NOTE 2: For best results, begin on January 1st of the year previous to the;
 *         date of the first transaction. This is the default.;
 * NOTE 3: CALENDAR_START_DATE should be set to a minimum of 3 months prior to;
 *         the dates of the earliest transactions in the initial data load.;

 /* Bank start date should be 5+ years back */
 /*%let CALENDAR_START_DATE=%sysfunc(intnx(year, %sysfunc(today()), -1, beginning), yymmddn.);*/
 %let CALENDAR_START_DATE='01JAN2007'd;
 %let calendar_end_date='31Dec2030'd;
 %let SASROOT=%sysget(SASROOT);
 %let segKCDBUser=BANK1KCTR;

/* APPEND - append */
 %macro append(source=,target=);
    proc append base=&target
                data=&source
                force;
    run;
 %mend;

/*---------------------------------------------------------------------------
  Customized FSC_JOB_CALENDAR
    - Bank Holidays defined
----------------------------------------------------------------------------*/
%global MON_FORMAT MON_LENGTH MON_LENGTH_S;
%let MON_LENGTH=3;

/* Number of days used for FSC_MONTH_DIM and FSK_JOB_CALENDAR. */
 data _null_;
    num_days=intck('day',&calendar_start_date,&calendar_end_date);
    call symputx('num_days',num_days);
 run;

%macro getloc;
   %let loc=%substr(%sysfunc(getpxLocale()),1,2);

   %if %lowcase(&loc) eq ar or
       %lowcase(&loc) eq es or
       %lowcase(&loc) eq fr or
       %lowcase(&loc) eq it or
       %lowcase(&loc) eq ja or
       %lowcase(&loc) eq ko or
       %lowcase(&loc) eq ru or
       %lowcase(&loc) eq zh %then %do;
      %let MON_FORMAT=NLDATEMN;
      %let MON_LENGTH_S=&MON_LENGTH.;
   %end;
   %else %do;
      %if %lowcase(&loc) ne en %then %do;
      %let _amlmsg_=NOTE: AML: LOCALE &loc. not supported EN will be installed.;
         %put ERROR: AML Error &_amlmsg_;
     %end;
      %let MON_FORMAT=MONNAME;
      %let MON_LENGTH=9;
      %let MON_LENGTH_S=3;
   %end;
%mend;
%getloc;

/* FSC_MONTH_DIM */
 data WORK.fsc_month_dim(drop=i calendar_date);

   if 1 eq 0 then
      set core.FSC_MONTH_DIM;

   do i=1 to %eval(&num_days);
      if i eq 1 then
         calendar_date=dhms(&calendar_start_date,00,00,00);
      else
         calendar_date=dhms(intnx('day',&calendar_start_date,i-1),00,00,00);

         month_key=trim(left(year(datepart(calendar_date))))||
              trim(left(put(month(datepart(calendar_date)),z2.0)));
         month_and_year=trim(left(put(month(datepart(calendar_date)),z2.0))||
                   trim(left(year(datepart(calendar_date)))));
         month_name=left(upcase(put(datepart(calendar_date),
                  &MON_FORMAT.&MON_LENGTH..)));
         month_name_3c=left(upcase(put(datepart(calendar_date),
                  &MON_FORMAT.&MON_LENGTH_S..)));
         quarter_name_2c='Q'||left(put(datepart(calendar_date),qtr1.));
         quarter_name_4c='Q'||left(put(datepart(calendar_date),qtr1.))||
                         left(put(datepart(calendar_date),year2.));
         year_2c=put(datepart(calendar_date),year2.);
         year_4c=put(datepart(calendar_date),year4.);
         segment_id="&segKCDBUser";
      if put(today(),month2.)=month(datepart(calendar_date)) and
         put(today(),year4.)=year(datepart(calendar_date)) then
         current_month_ind = 'Y';
      else
         current_month_ind = 'N';
      output;
   end;
   stop;
 run;

 proc sort data=WORK.fsc_month_dim nodupkey;
    by month_key;
 run;

/* APPEND - append */
 %append(source=WORK.FSC_MONTH_DIM,
         target=core.FSC_MONTH_DIM);

/* Calculate holiday date */
/*  Rules
          If Holiday is on a Sunday, it will be observed on the following Monday
      If Holiday is on a Saturday, same date is used

Here is the list of the ten Holidays and the rules for them at Bank.
1.             New Year's Day                      January 1st
2.             Dr. Martin Luther King, Jr. Day     3rd Monday in January
3.             Presidents' Day                     3rd Monday in February
4.             Memorial Day                        Last Monday in May
5.             Independence Day                    July 4
6.             Labor Day                           1st Monday in September
7.             Columbus Day                        2nd Monday in October
8.             Veteran's Day                       November 11
9.             Thanksgiving Day                    4th Thursday in November
10.            Christmas Day                       December 25   */;

data holiday_calendar;

   do i=1 to %eval(&num_days);
  if i eq 1 then
     calendar_date=dhms(&calendar_start_date,00,00,00);
  else
     calendar_date=dhms(intnx('day',&calendar_start_date,i-1),00,00,00);

   week_day=weekday(datepart(calendar_date));
   year = year(datepart(calendar_date));

   holiday_date = datepart(calendar_date);

   /* Specific dates for holiday */
/*   if holiday_date = '05JUL2021'd then delete;*/

   if ((holiday_date = holiday('newyear', year)) OR
       (holiday_date = holiday('usindependence', year)) OR
           (holiday_date = holiday('veterans', year)) OR
       (holiday_date = holiday('christmas', year)) ) then do;

        if week_day=1 then do;
            next_date = intnx('day',holiday_date,1);
            holiday_date = next_date;
            put holiday_date next_date;
        end;
   if holiday_date ne '05JUL2021'd then output;
   end;

   if holiday_date = holiday('uspresidents', year) then output;
   if holiday_date = holiday('mlk', year) then output;
   if holiday_date = holiday('memorial', year) then output;
   if holiday_date = holiday('labor', year) then output;
   if holiday_date = holiday('columbus', year) then output;
   if holiday_date = holiday('thanksgiving', year) then output;

end;
keep holiday_date;
run;

proc sql noprint;
 select distinct(holiday_date) INTO: holiday_dt separated by ','
from holiday_calendar;
quit;
proc print data=holiday_calendar; 
Title 'Holiday Dates';
format holiday_date date9.; 
var holiday_date; 
/*where holiday_date >= '01JAN2019'd and holiday_date <= '31DEC2021'd;*/
run;

/* Calculate 1st business day of each month */
options nosymbolgen mprint;
data work.month_calendar;
    do i=1 to &num_days;
       if i eq 1 then
          calendar_date=dhms(&calendar_start_date,00,00,00);
       else
          calendar_date=dhms(intnx('day',&calendar_start_date,i-1),00,00,00);

       week_day=weekday(datepart(calendar_date));

    /* Set monthly processing for 1st business day of each month */
       if day(datepart(calendar_date)) eq 1 then do;

           /* if day=Sunday then advance by 1 */
             if week_day = 1 then next_date = intnx('day',datepart(calendar_date),1);
                else if week_day = 7 then next_date = intnx('day',datepart(calendar_date),2);
                else if week_day = 6 and datepart(calendar_date) IN (&holiday_dt.)
                     then next_date = intnx('day',datepart(calendar_date),3);
                else next_date = datepart(calendar_date);

        if next_date IN (&holiday_dt.) then monthly_date = intnx('day',next_date,1);
                                       else monthly_date = next_date;
        output;
        end;
        keep monthly_date;
  end;
run;

proc sql noprint;
 select distinct(monthly_date) INTO: monthly_dt separated by ','
from month_calendar;
quit;

/* FSC_JOB_CALENDAR */;
 data WORK.fsc_job_calendar(drop=i week_day b_day_count previous_date);
 
    attrib  calendar_date   length=8.   format=datetime18.    informat=datetime18.;
  
    if 1 eq 0 then
       set core.FSC_JOB_CALENDAR;

    retain b_day_count 0;

    do i=1 to &num_days;
       job_calendar_id=i;
       if i eq 1 then
          calendar_date=dhms(&calendar_start_date,00,00,00);
       else
          calendar_date=dhms(intnx('day',&calendar_start_date,i-1),00,00,00);

       week_day=weekday(datepart(calendar_date));
       segment_id="&segKCDBUser";

           previous_date = intnx('day',datepart(calendar_date),-1);

      /* Set monthly processing for 1st business day of each month */
       if (datepart(calendar_date) in (&monthly_dt)) then do;
          monthly_rundate_ind='Y';
          rundate_ind='Y';
       end;
       else monthly_rundate_ind='N';

       if (week_day not in(1,7) and datepart(calendar_date) not in (&holiday_dt)) then do;
          daily_rundate_ind='Y';
          rundate_ind='Y';
          if week_day eq 2 then do;
            /* Run Weekly Each Monday */
             weekly_rundate_ind='Y';
             rundate_ind='Y';
          end;
          else if week_day eq 3 and previous_date IN (&holiday_dt) then do; /* Monday was a holiday */
             weekly_rundate_ind='Y';
             rundate_ind='Y';
                  end;
                  else weekly_rundate_ind='N';
          b_day_count + 1;
          business_day_count=b_day_count;
          status_ind='N';
          output;
       end;
       else do;
          daily_rundate_ind='N';
          weekly_rundate_ind='N';
          monthly_rundate_ind='N';
          status_ind='N';
          rundate_ind='N';
          business_day_count=-1;
          output;
       end;
    end;
    stop;
 run;

 proc sort data=WORK.FSC_JOB_CALENDAR; by job_calendar_id; run;

 %append(source=WORK.FSC_JOB_CALENDAR,
           target=core.FSC_JOB_CALENDAR);

/* Set first Runasofdate */;
proc sql;
   update core.fsc_job_calendar set status_ind ='N';

   update core.fsc_job_calendar set status_ind='Y'
   where datepart(calendar_date) le '06JUL2020'd;
quit;

/******************************************************************************/
/* BEGIN: SEED DATA                                                           */
/******************************************************************************/;
%let calendar_start_date=20070101;
/* Obtain the number of days to include in FSC_DATE_DIM */
 data _null_;
    calendar_start_date=input(put(&calendar_start_date,8.),yymmdd8.);
    calendar_end_date=intnx('day',intnx('year',calendar_start_date,20),-1);
    num_days=intck('day',calendar_start_date,calendar_end_date) + 1;

    call symputx('num_days',num_days);
 run;

/* Build FSC_DATE_DIM table */;
 data WORK.fsc_date_dim(drop=i);
    attrib  calendar_date   length=8.   format=datetime18.    informat=datetime18.;
    if 1 eq 0 then
       set core.FSC_DATE_DIM;

    do i=1 to %eval(&num_days);
       if i eq 1 then
          calendar_date=dhms(input(put(&calendar_start_date,8.),yymmdd8.)
                             ,00,00,00);
       else
       calendar_date=dhms(intnx('day',input(put(&calendar_start_date,8.),
                          yymmdd8.),i - 1),00,00,00);
       date_key=trim(left(year(datepart(calendar_date))))||
                trim(left(put(month(datepart(calendar_date)),z2.0))||
                trim(left(put(day(datepart(calendar_date)),z2.0))));
       calendar_date_sas=datepart(calendar_date);
       calendar_date_dmy=put(datepart(calendar_date),date9.);
       day_name=upcase(left(put(datepart(calendar_date),downame9.)));
       day_name_short=upcase(left(put(datepart(calendar_date),downame3.)));
       day_number_in_month=put(day(datepart(calendar_date)),z2.0);
       day_number_in_year=put(datepart(calendar_date),julday3.);
       week_number_in_month=ceil(day(datepart(calendar_date))/7);
       week_number_in_year=ceil(put(datepart(calendar_date),julday3.)/7);
       month_number_in_year=month(datepart(calendar_date));
       month_key=trim(left(year(datepart(calendar_date))))||
                 trim(left(put(month(datepart(calendar_date)),z2.0)));
       month_and_year=trim(left(put(month(datepart(calendar_date)),z2.0))||
                      trim(left(year(datepart(calendar_date)))));
       month_name=left(upcase(put(datepart(calendar_date),monname9.)));
       month_name_short=left(upcase(put(datepart(calendar_date),monname3.)));
       quarter_name='Q'||left(put(datepart(calendar_date),qtr1.))||
                         left(put(datepart(calendar_date),year2.));
       quarter_and_year='Q'||left(put(datepart(calendar_date),qtr1.))||
                         left(put(datepart(calendar_date),year4.));
       month_name_3c='';
       quarter_name_2c='';
       quarter_name_4c='';
       year_2c=put(datepart(calendar_date),year2.);
       year_4c=put(datepart(calendar_date),year4.);
       holiday_ind='N';
       holiday_name='';
       if put(datepart(calendar_date),weekday1.) not in (1,7) then
          week_day_ind='Y';
       else
          week_day_ind = 'N';
       if day(datepart(calendar_date + 86400)) eq 1 then
          end_of_month_ind='Y';
       else
          end_of_month_ind = 'N';
       economic_release_desc = '';
       economic_event_desc   = '';
       output;
    end;
 run;

 proc sort data=WORK.fsc_date_dim nodupkey;
    by date_key;
 run;

 %append(source=WORK.FSC_DATE_DIM,
         target=core.FSC_DATE_DIM);
 %append(source=CMNDATA.FSC_TIME_DIM,
         target=core.FSC_TIME_DIM);

/* Append Seed Data to CORE */;
/* data work.fsc_country_dim; */
/*     if 1 eq 0 then set core.fsc_country_dim; */
/*     set cmndata.fsc_country_dim; */
/*     crr_risk_value = 'N'; */
/*     risk_classification = 'N'; */
/*     risk_value = 0; */
/*     change_begin_date=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00); */
/*     change_end_date='01JAN5999:00:00:00'DT; */
/*     change_current_ind='Y'; */
/* run; */
/*  */
/* proc sort data=work.fsc_country_dim; */
/*     by country_key change_current_ind; */
/* run; */

/*--------------------------------------------------------------------------
  FSC_SCD_COLUMNS logic
---------------------------------------------------------------------------*/
%let dims=fsc_account_dim
fsc_party_dim 
fsc_branch_dim 
fsc_household_dim 
fsc_associate_dim 
fsc_party_addendum_dim 
fsc_party_assoc
fsc_address_dim 
fsc_bank_dim
fsc_party_segment_dim
fsc_ext_party_account_dim 
fsc_country_dim 
pub_party_segment_crr_dom
fsc_entity_watch_list_dim 
fsc_location_watch_list_dim 
fsc_transaction_type_dim 
fsc_party_account_bridge
fsc_household_account_bridge
fsc_household_party_bridge;

%macro createscd(dims=);
proc datasets lib=work nolist nodetails nowarn;
  delete fsc_scd_columns_all;
quit;
data work.fsc_scd_columns_all;
  if 1=0 then set core.fsc_scd_columns;
  stop;
run;

/* Populate all Dimension tables columns into work.FSC_SCD_COLUMNS */
%let i=1;
%let cdim=%scan(&dims,&i); 
%do %while (&cdim ne ) ;
   %getnames(dimname=&cdim, output=&cdim);

   proc append data=work.&cdim base=work.fsc_scd_columns_all force;run;

   %let i = %eval(&i+1);
   %let cdim=%scan(&dims,&i); 
%end;
%mend;

%macro getnames(dimname=,output=);
proc contents data=core.&dimname.
              out=work.tmp(keep=memname name rename=(memname=scd_table name=scd_column)) noprint;
run;

proc datasets library=work;
  modify tmp;
  label scd_table='Table Name';
  label scd_column='Column Name';
quit;

data work.&output;
   if 1=0  then set core.fsc_scd_columns;
   set work.tmp;

   retain order_id 0;

   scd_table=upcase(scd_table);
   scd_column=upcase(scd_column);

  /* SCD Column exclusions */
   if lowcase(scd_column) not in ('change_current_ind',
                                  'change_begin_date',
                                  'change_end_date',
                                  "account_key",
                                  "account_number",
                                  "party_key",
                                  "party_number",
                                  "party_addendum_key",
                                  "household_key",
                                  "household_number",
                                  "address_key",
                                  "address_number",
                                  "associate_key",
                                  "branch_key",
                                  "country_key",
                                  "transaction_type_key",
                                  "entity_watch_list_key",
                                  "entity_watch_list_number",
                                  "location_watch_list_key",
                                  "location_watch_list_number",
                                  "ext_party_account_key",
                                  "ext_party_account_comp_key",
                                  "external_party_number",
                                  "country_code_2",
                                  "country_code_3",
                                  "runasofdt_record_loaded",
                                  "runasofdt_record_recv"
                                  );
   /* SCD Table / columns exclusions */
   if (lowcase(scd_table) eq 'fsc_associate_dim' and lowcase(scd_column) eq 'associate_number') then do; delete; end;
   if (lowcase(scd_table) eq 'fsc_branch_dim' and lowcase(scd_column) eq 'branch_number') then do; delete; end;
   /* FSC_ENTITY_WATCH_LIST_DIM Key columns - no SCD */
   if (lowcase(scd_table) eq 'fsc_entity_watch_list_dim' 
          and lowcase(scd_column) in ('entity_watch_list_number' 'first_name' 'middle_name' 'last_name' 'address' 'city_name' 'state_name' 'postal_code' 'country_name' 'full_address'
                'date_of_birth' 'year_of_birth' 'place_of_birth' 'citizenship_country_name')) then do; delete; end;

   scd_type='type1';
   if find(scd_table,'BRIDGE') > 0 then scd_type='type2';
   if scd_column in('PSD_UPDATE_DATE' 'PSD_INSERT_DATE' 'STGTBL_INSERT_DT') then scd_type='updt';
   if find(scd_column,'MATCH_CODE') > 0 then scd_type='updt';
   if scd_column eq 'SEGMENT_ID' then scd_type='type1';
   segment_id="BANK1KCTR";
   order_id=order_id+1;
   xref_valid_ind='N';
   create_date = &sys_date.;
   end_date = &sys_date.;
   create_user_id='pubrun';
   version_number=1;
   current_ind='Y'; 
run;
%mend;

%createscd(dims=&dims);

data work.fsc_scd_columns_load;
  set work.fsc_scd_columns_all;
  scd_key = _n_;
run;

proc sort data=work.fsc_scd_columns_load;
by scd_table scd_column;
run;

/* End of SCD created anew Proc Apppend  work.fsc_scd_columns_load */

 %append(source=CMNDATA.fsc_country_dim,
         target=core.FSC_COUNTRY_DIM);
 %append(source=CMNDATA.FSC_CURRENCY_DIM,
        target=core.FSC_CURRENCY_DIM);
 %append(source=CMNDATA.FSC_TRANSACTION_STATUS_DIM,
         target=core.FSC_TRANSACTION_STATUS_DIM);
 %append(source=CMNDATA.FSC_TRANSACTION_TYPE_DIM,
         target=core.FSC_TRANSACTION_TYPE_DIM);
 %append(source=work.FSC_SCD_COLUMNS_LOAD,
         target=core.FSC_SCD_COLUMNS);


/*----------------------------------------------------------------------------------
  Load core.fsc_job
-----------------------------------------------------------------------------------*/;
/* data work.fsc_job; */
/*    if 1=2 then set core.fsc_job; */
/*    infile datalines delimiter=',' DSD truncover; */
/*    input job_id job_name $ job_desc $ job_cat $ job_include; */
/*    datalines; */
/* 10,FSC_COUNTRY_DIM,'Manage FSC_COUNTRY_DIM','Fs Core ETL',0     */
/* 15,FSC_ACCOUNT_DIM,'Manage FSC_ACCOUNT_DIM','FS Core ETL',0 */
/* 20,FSC_PARTY_DIM,'Manage FSC_PARTY_DIM','FS Core ETL',0 */
/* 25,FSC_PARTY_ADDENDUM_DIM,'Manage FSC_PARTY_ADDENDUM_DIM','FS Core ETL',0 */
/* 30,FSC_ADDRESS_DIM,'Manage FSC_ADDRESS_DIM','FS Core ETL',0 */
/* 35,FSC_ASSOCIATE_DIM,'Manage FSC_ASSOCIATE_DIM','FS Core ETL',0 */
/* 40,FSC_BRANCH_DIM,'Manage FSC_BRANCH_DIM','FS Core ETL',0 */
/* 45,FSC_PARTY_ASSOC_DIM,'Manage FSC_PARTY_ASSOC_DIM','FS Core ETL',0 */
/* 50,FSC_PARTY_ACCOUNT_BRIDGE,'Manage FSC_PARTY_ACCOUNT_BRIDGE','FS Core ETL',0 */
/* 55,FSC_CASH_FLOW_FACT,'Manage FSC_CASH_FLOW_FACT','FS Core ETL',0 */
/* 60,FSC_ACCOUNT_PROFILE_FACT,'Manage FSC_ACCOUNT_PROFILE_FACT','FS Core ETL',0 */
/* 70,FSC_REFERRAL_STAGE,'Manage FSC_REFERRAL_STAGE','FS Core ETL',0 */
/* 71,FSC_REFERRAL_SUSPECT_STAGE,'Manage FSC_REFERRAL_SUSPECT_STAGE','FS Core ETL',0 */
/* 72,FSC_REFERRAL_TRANSACTION_STAGE,'Manage FSC_REFERRAL_TRANSACTION_STAGE','FS Core ETL',0 */
/* 73,FSC_REFERRAL_ATTACHMENTS,'Manage FSC_REFERRAL_ATTACHMENTS','FS Core ETL',0 */
/* 80,PUB_SUBPOENA_STAGE,'Manage PUB_SUBPOENA_STAGE','FS Core ETL',0 */
/* 85,PUB_AI_TRANS_SUM,'Manage PUB_AI_TRANS_SUM','FS Core ETL',0 */
/* 90,PUB_INTERNAL_ACCOUNTS,'Manage PUB_INTERNAL_ACCOUNTS','FS Core ETL',0 */
/* 95,PUB_PARTY_SEGMENT_CRR_DOM,'Manage PUB_PARTY_SEGMENT_CRR_DOM','FS Core ETL',0 */
/* 100,FSC_SAR_SUM,'Manage FSC_SAR_SUM','FS Core ETL',0 */
/* 101,FSC_CTR_SUM,'Manage FSC_CTR_SUM','FS Core ETL',0 */
/* 105,DAILY_DWJN,'Manage DWJN Daily Feed','FS Core ETL',0 */
/* 110,MONTHLY_DWJN,'Manage DWJN Monthly Reconciliation','FS Core ETL',0 */
/* 115,DAILY_ADVN,'Manage ADVN Daily Feed','FS Core ETL',0 */
/* 120,MONTHLY_ADVN,'Manage ADVN Monthly Reconciliation','FS Core ETL',0 */
/* 125,PUB_314A,'Manage PUB_314A','FS Core ETL',0 */
/* 175,AML_PREP_FILES,'Runs build of all prep files','AML Prep Files',0 */
/* 200,AML_AGP,'runs AML AGP','AML AGP',1 */
/* 900,PUB_PROCESS_REPORTING,'Report Job Durations/Statistics','BATCH JOBS',0 */
/* ; */
/* RUN; */
/*  */
/* %append(source=work.FSC_JOB, */
/*         target=core.FSC_JOB); */
/*  */
/*-----------------------------------------------------------------------------------
  Create UNKNOWN ROWS
-----------------------------------------------------------------------------------*/;
/*
data fsc_account_dim;
   if 1=2 then set core.fsc_account_dim;
   account_key=-1;
   account_number='UNKNOWN';
   segment_id="&segKCDBUser";
   account_type_desc='UNKNOWN';
   account_currency_code='UNK';
   account_currency_name='UNKNOWN';
   psd_insert_date = datetime();
   psd_update_date = datetime();
   runasofdt_record_loaded = "&defaultBegindate"dt;
   runasofdt_record_recv = "&defaultBegindate"dt;
   stgtbl_insert_dt = datetime();
   change_current_ind='Y';
   CHANGE_BEGIN_DATE=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00);
   change_end_date='01JAN5999 00:00:00'dt;
   output;
   stop;
run;

%append(source=work.fsc_account_dim,
        target=core.FSC_ACCOUNT_DIM);

data fsc_party_dim;
   if 1=2 then set core.fsc_party_dim;
   party_key=-1;
   party_number='UNKNOWN';
   segment_id="&segKCDBUser";
   party_type_desc='UNKNOWN';
   politically_exposed_person_ind='N';
   psd_insert_date = datetime();
   psd_update_date = datetime();
   runasofdt_record_loaded = "&defaultBegindate"dt;
   runasofdt_record_recv = "&defaultBegindate"dt;
   stgtbl_insert_dt = datetime();
   change_current_ind='Y';
   CHANGE_BEGIN_DATE=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00);
   change_end_date='01JAN5999 00:00:00'dt;
   output;
   stop;
run;

%append(source=work.fsc_party_dim,
        target=core.FSC_PARTY_DIM);

data fsc_household_dim;
   if 1=2 then set core.fsc_household_dim;
   household_key=-1;
   household_number='UNKNOWN';
   segment_id="&segKCDBUser";
   psd_insert_date = datetime();
   psd_update_date = datetime();
   runasofdt_record_loaded = "&defaultBegindate"dt;
   runasofdt_record_recv = "&defaultBegindate"dt;
   stgtbl_insert_dt = datetime();
   change_current_ind='Y';
   CHANGE_BEGIN_DATE=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00);
   change_end_date='01JAN5999 00:00:00'dt;
   output;
   stop;
run;

%append(source=work.fsc_household_dim,
        target=core.FSC_HOUSEHOLD_DIM);

data fsc_ext_party_account_dim;
   if 1=2 then set core.fsc_ext_party_account_dim;
   ext_party_account_key=-1;
   external_party_number='UNKNOWN';
   segment_id="&segKCDBUser";
   create_dttm='12DEC2019:00:00:00'dt;   
   psd_insert_date = datetime();
   psd_update_date = datetime();
   runasofdt_record_loaded = "&defaultBegindate"dt;
   runasofdt_record_recv = "&defaultBegindate"dt;
   stgtbl_insert_dt = datetime();
   change_current_ind='Y';
   CHANGE_BEGIN_DATE=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00);
   change_end_date='01JAN5999 00:00:00'dt;
   output;
   stop;
run;

%append(source=work.fsc_ext_party_account_dim,
        target=core.FSC_EXT_PARTY_ACCOUNT_DIM);

data fsc_associate_dim;
   if 1=2 then set core.fsc_associate_dim;
   associate_key=-1;
   associate_number='UNKNOWN';
   segment_id="&segKCDBUser";
   psd_insert_date = datetime();
   psd_update_date = datetime();
   runasofdt_record_loaded = "&defaultBegindate"dt;
   runasofdt_record_recv = "&defaultBegindate"dt;
   stgtbl_insert_dt = datetime();
   change_current_ind='Y';
   CHANGE_BEGIN_DATE=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00);
   change_end_date='01JAN5999 00:00:00'dt;
   output;
   stop;
run;

%append(source=work.fsc_associate_dim,
        target=core.FSC_ASSOCIATE_DIM);

data fsc_address_dim;
   if 1=2 then set core.fsc_address_dim;
   address_key=-1;
   address_number='UNKNOWN';
   segment_id="&segKCDBUser";
   psd_insert_date = datetime();
   psd_update_date = datetime();
   runasofdt_record_loaded = "&defaultBegindate"dt;
   runasofdt_record_recv = "&defaultBegindate"dt;
   stgtbl_insert_dt = datetime();
   change_current_ind='Y';
   CHANGE_BEGIN_DATE=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00);
   change_end_date='01JAN5999 00:00:00'dt;
   output;
   stop;
run;

%append(source=work.fsc_address_dim,
        target=core.FSC_ADDRESS_DIM);

data fsc_bank_dim;
   if 1=2 then set core.fsc_bank_dim;
   bank_key=-1;
   bank_number='UNKNOWN';
   segment_id="&segKCDBUser";
   psd_insert_date = datetime();
   psd_update_date = datetime();
   runasofdt_record_loaded = "&defaultBegindate"dt;
   runasofdt_record_recv = "&defaultBegindate"dt;
   stgtbl_insert_dt = datetime();
   change_current_ind='Y';
   CHANGE_BEGIN_DATE=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00);
   change_end_date='01JAN5999 00:00:00'dt;
   output;
   stop;
run;

%append(source=work.fsc_bank_dim,
        target=core.FSC_BANK_DIM);

data fsc_branch_dim;
   if 1=2 then set core.fsc_branch_dim;
   branch_key=-1;
   branch_number='UNKNOWN';
   segment_id="&segKCDBUser";
   risk_value=0;
   psd_insert_date = datetime();
   psd_update_date = datetime();
   runasofdt_record_loaded = "&defaultBegindate"dt;
   runasofdt_record_recv = "&defaultBegindate"dt;
   stgtbl_insert_dt = datetime();
   change_current_ind='Y';
   CHANGE_BEGIN_DATE=dhms(input(put(&calendar_start_date,8.),yymmdd8.),00,00,00);
   change_end_date='01JAN5999 00:00:00'dt;
   output;
   stop;
run;

%append(source=work.fsc_branch_dim,
        target=core.FSC_BRANCH_DIM);
*/
