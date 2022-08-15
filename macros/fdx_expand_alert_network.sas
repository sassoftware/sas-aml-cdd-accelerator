/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Add files to SAS Visual Investigator object
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_expand_alert_network(max_iter=10,in_ds=work.pab_alerts,out_ds=work.alert_network_exp);
/*create initial 1st level network dataset*/
proc sql;
create table prev as 
select distinct 
	l.alert_id as l_alert_id,
	r.alert_id as r_alert_id
from &in_ds. l 
inner join &in_ds. r 
	on l.transaction_key=r.transaction_key
;
quit;

/*loop through expansion until record count does not change, or max_iter is reached*/
%do i=1 %to &max_iter;
%put NOTE: iteration &i.;
/*get count from previous iteration*/
proc sql noprint; select count(*) into :prev_count from work.prev; quit;

/*expand alert network*/
proc sql;
create table current as 
select 
     l.l_alert_id,
     case
           when r.r_alert_id is null
                then l.r_alert_id
           else r.r_alert_id
       end as r_alert_id
from prev r 
inner join prev l
     on r.l_alert_id = l.r_alert_id
;
quit;

/*append expansion to previous iteration*/
proc append base=work.prev data=work.current force;
run;

/*dedup*/
proc sort data=work.prev nodup;
by l_alert_id r_alert_id; 
run;

/*get count from current iteration*/
proc sql noprint; select count(*) into :current_count from work.prev; quit;

/*if count from current iteration = count from previous iteration then we are done expanding*/
%if &current_count = &prev_count %then %GOTO EXIT;

%end;

%EXIT:

/*output final dataset*/

proc sql;
create table &out_ds as 
select 
     l_alert_id,
     r_alert_id
from prev 
;quit;

proc datasets nolist;
delete prev current;
run;

%mend;

/*%fdx_expand_alert_network(max_iter=10,in_ds=ctr_pty_alerts,out_ds=work.alert_network_exp);*/


