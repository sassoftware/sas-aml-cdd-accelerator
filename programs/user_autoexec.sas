/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PURPOSE      : Job Autoexec
/ DESCRIPTION  : Stage various macros and database connections needed for downstream processing.
/                This program evolved from many contributors and is called directly from jobexec.sh.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:    %user_autoexec;
/--------------------------------------------------------------------------------------------------------------------
/ HISTORY
/--------------------------------------------------------------------------------------------------------------------
/
/--------------------------------------------------------------------------------------------------------------------*/

%global
    basedir tenant rundate runasofdate
    PGdbFlavor PGdbHost PGdbPort PGdbAuth PGdbTenant PGdbConnOps
    ws_base_url ws_user ws_password ws_token ws_token_dttm access_token 
;

%macro user_autoexec();

/*--------------------------
 * Setup Environment
 *--------------------------*/

%let basedir=%sysget(_BASEDIR);
%let _user=%sysget(_USER);
%let pghost=%sysget(PGHOST);
%let ws_base_url=%sysfunc(getoption(servicesbaseurl));

%let tenant=%scan(&sysparm,1);

%macro isBlank(param);
 %sysevalf(%superq(param)=,boolean)
%mend isBlank;

%if %isBlank(&basedir) %then %do;
	%put "ERROR: The Base Directory was not specified.";
	%goto MACRO_END;
%end;

%if %isBlank(&tenant) %then %do;
	%put "ERROR: A tenant was not defined at invocation.";
	%goto MACRO_END;
%end;

%if %isBlank(&_user) %then %do;
        %put "ERROR: The _USER variable was not defined at invocation.";
        %goto MACRO_END;
%end;

%let prev_autocall_path = %sysfunc(kcompress(%sysfunc(getoption(sasautos)),%str(%(%))));
options SASAUTOS=(
  "&basedir./macros",
  "/opt/sas/spre/home/SASFoundation/ucmacros/amlcoresrv",
  "/opt/sas/&tenant./config/data/amlcoresrv/ucmacros",
  &prev_autocall_path
);

/*--------------------------
 * Debug Options
 *--------------------------*/

options mstored dbidirectexec compress=yes mexecsize=128K minoperator;
%let debug_parm = %upcase(%scan(&sysparm,2));
%put &=debug_parm.;
%fdx_set_debug_params;

/*--------------------------
 * Bulkload Options
 *--------------------------*/

/* Sets BL_OPTIONS on PROC APPEND statements, equivalent to OPTIONS statement in Oracle control file */

%global bulkloadThreshold
        bl_options_dimension
        bl_options_account_analysis_dim
        bl_options_cash_flow_fact
        bl_options_alert
        bl_options_alert_comment
;

%let bulkloadThreshold=10000000;/*500 default moving to 10 M to keep from using BL till we have fix*/
%let bl_options_dimension = %str(); /*BL_RETURN_WARNINGS_AS_ERRORS=YES BL_DELETE_FILES=NO BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=0, ROWS=50000'*/
%let bl_options_account_analysis_dim = %str();/*BL_RETURN_WARNINGS_AS_ERRORS=YES BL_DELETE_FILES=NO BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=0, ROWS=5000'*/
%let bl_options_cash_flow_fact = %str();/*BL_RETURN_WARNINGS_AS_ERRORS=YES BL_DELETE_FILES=NO BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=0, ROWS=50000'*/
%let bl_options_alert = %str();/*BL_RETURN_WARNINGS_AS_ERRORS=YES BL_DELETE_FILES=NO BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=0, ROWS=500'*/
%let bl_options_alert_comment = %str();/*BL_RETURN_WARNINGS_AS_ERRORS=YES BL_DELETE_FILES=NO BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=0, ROWS=500'*/
%let defaultEndDate=01JAN5999 00:00:00;
%let defaultBeginDate=10OCT2019 00:00:00;
%let useRundate=Y;
%let bat_abort=N;
%let ppid=0;

/*--------------------------
 * Oauth Access Token
 *--------------------------*/

%fdx_ws_get_oauth_token();

/*--------------------------
 * Postgres Connections
 *--------------------------*/

/*
fcf_autoexec - sets core, corevw

------- Below all calls the fcf_autoexec --------
aml_autoexec - sets watchlist, amlkc, amlprep
cdd_autoexec - sets cddkc, cddprep
rr_autoexec - sets fdhmetadata, fdhdata
fcf_va_autoexec - sets caslib: fdhdata, fdhmetadata, svi_alerts, svi_vsd_service
aml_alert_triage_autoexec - sets core, svi_alerts, kc
aml_71_autoexec - used with AML 7 code porting
aml_segmentation_autoexec - sets core, svi_alerts
*/

%let PGdbFlavor=postgres;
%let PGdbAuth=PGdbAuth;
%let PGdbHost=&pghost;
%let PGdbTenant=&tenant.;
%let PGdbPort=5431;
%let PGdbConnOpts=%str(
     server="&PGdbHost." 
     port=&PGdbPort. 
     authdomain="&PGdbAuth." 
     conopts='UseDeclareFetch=1;sslmode=required' 
     DBMAX_TEXT=32767
     );

libname ids &PGdbFlavor. &PGdbConnOpts. schema="identities" database="SharedServices";
libname audit &PGdbFlavor. &PGdbConnOpts. schema="audit" database="SharedServices";
libname logon &PGdbFlavor. &PGdbConnOpts. schema="logon" database="SharedServices";

libname fdhmeta &PGdbFlavor. &PGdbConnOpts. schema="fdhmetadata" database="&PGdbTenant.";
libname fdhdata &PGdbFlavor. &PGdbConnOpts. schema="fdhdata" database="&PGdbTenant.";
libname fdhhist &PGdbFlavor. &PGdbConnOpts. schema="fdhhistory" database="&PGdbTenant.";
libname alerts &PGdbFlavor. &PGdbConnOpts. schema="svi_alerts" database="&PGdbTenant.";
libname scnario &PGdbFlavor. &PGdbConnOpts. schema="svi_vsd_service" database="&PGdbTenant.";


/*--------------------------
 * Directory Paths
 *--------------------------*/
/*options to create library directory if it doesn't exist*/
options dlcreatedir;

options set=FCFROOT "&basedir.";
%let FCFROOT=%sysfunc(sysget(FCFROOT));
options set=CMNROOT "&basedir.";
%let CMNROOT=%sysfunc(sysget(CMNROOT));
options set=FCFDATA "&basedir./data";
%let FCFDATA=%sysfunc(sysget(FCFDATA));
options set=FCFLAND "&basedir./data";
%let FCFLAND=%sysfunc(sysget(FCFLAND));

/*--------------------------
 * Set sys_date
 *--------------------------*/
data _null_;
attrib sys_date    length=8.     format=datetime18.     informat=datetime18.;
sys_date = datetime();
call symput ('sys_date' ,sys_date);
put sys_date=;
run;

/*--------------------------
 * Set PID
 *--------------------------*/
%let PID = &SYSJOBID;

/*--------------------------
 * Formats
 *--------------------------*/
libname custsrc '!FCFROOT/source';

/*--------------------------
 * Formats
 *--------------------------*/
libname fmts '!FCFROOT/formats' filelockwait=3;

/*--------------------------
 * Job Stats
 *--------------------------*/
libname job_stat '!FCFROOT/etlops';

/*--------------------------
 * Common Data
 *--------------------------*/
libname cmndata '!FCFDATA';

/*--------------------------
 * Master
 *--------------------------*/
libname mst_aler '!FCFDATA/master/alert';
libname mst_prep '!FCFDATA/master/prep';
libname mst_rpt  '!FCFDATA/master/report';
libname mst_rc   '!FCFDATA/master/rc';
libname mst_nbrs '!FCFDATA/master/nn';
libname mst_ca   '!FCFDATA/master/ca';

/*--------------------------
 * Stage
 *--------------------------*/
libname stg_aler '!FCFDATA/stage/alert';
libname stg_bdg  '!FCFDATA/stage/bridge';
libname stg_ctrl '!FCFDATA/stage/control';
libname stg_dim  '!FCFDATA/stage/dim';
libname stg_fact '!FCFDATA/stage/fact';
libname stg_wtch '!FCFDATA/stage/watchlist';
libname stg_err  '!FCFDATA/stage/error';
libname stg_rc   '!FCFDATA/stage/rc';
libname stgrcacc '!FCFDATA/stage/rc/acc';
libname stgrcppf '!FCFDATA/stage/rc/ppf';
libname stgrcpty '!FCFDATA/stage/rc/pty';
libname stg_ca   '!FCFDATA/stage/ca';
libname stg_xref '!FCFDATA/stage/xref';
libname stg_hist '!FCFDATA/stage/hist_core_stg';

/*---------------------
 * Match Code Settings
 *---------------------*/
options DQLOCALE=(ENUSA);
options DQSETUPLOC="/opt/sas/spre/home/share/refdata/qkb/ci/31";
%let dqsetup=;

/*----------------------------------------------------------------------
 * Routing
 * By default, automatically route new alerts to current investigator.
 * Y - Default, automatically route new alerts to current investigator.
 * N - Do NOT automatically route new alerts to current investigator.
 *----------------------------------------------------------------------*/
%let autoroute2currentinvestigator = N;

/*------------------------------------------------------------------
 * Enable Formats
 * N - Formats are not enabled - valid during installation.
 * Y - Enable formats after the install.sas successfully completes.
 *------------------------------------------------------------------*/
%let enable_formats=Y;

/*---------------------------------------------------------------------------
 * Enable Base Currency
 * N - Base Currency is not enabled - valid during installation.
 * Y - Base Currency available after the install.sas successfully completes.
 *---------------------------------------------------------------------------*/
%let enable_base_currency=Y;

/*----------------------------------------------------------------------
 * Set get_scenario_performance_stats to Y so fcf_agp_codegen generates
 * code to gather performance statistics for scenarios.
 *----------------------------------------------------------------------*/
%let get_scenario_performance_stats = N;

/*----------------
 * Get RUNASOFDATE
 *----------------*/
/*
%fdx_get_runasofdate;
%put NOTE: rundate=&rundate. | runasofdate=&runasofdate.;
*/

%MACRO_END:
%mend;
%user_autoexec();
