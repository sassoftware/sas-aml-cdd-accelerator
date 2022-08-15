/*------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : KRISTEN MOODY (kristen.moody@sas.com)
/ PURPOSE      : Create Cash Transaction Investigation object based on results in ctr_prep.sas 
/
|------------------------------------------------------------------------------------------|
|  MAINTENANCE HISTORY                                                                     |
|------------------------------------------------------------------------------------------| 

|------------------------------------------------------------------------------------------|
|-----------------------------------------------------------------------------------------*/
proc printto log='/sso/data/krmood/logs/fdx_ctr_create_log.txt';
/*TODO: remove after testing*/
%global
	core_db
	ctr_currency_acct
	ctr_account_type_desc
	ctr_primary_med_desc
	ctr_status_desc
	cashcheck_inclusion
	ctr_amount
	runasofdate
	rundate
	ora_rundate
	worklib;

/*TODO: Comment Out - should be in Reference List*/
%let ctr_currency_acct='N','Y';
%let ctr_account_type_desc='C','P';
%let ctr_primary_med_desc='CASH';
%let ctr_status_desc='REENTRY','SUCCESS';
%let ctr_amount=10000;
%let worklib=stage;

%macro fdx_ctr_create();

%put NOTE: {BEGIN: FDX_CTI_CREATE PROGRAM};

/*format rundate for oracle*/
data _null_;
length rundate $9 ora_rundate $11;
rundate=substr(strip("&rundate."),1,9);
ora_rundate=cats("'", rundate, "'") ;
call symputx('ora_rundate',ora_rundate,'G');
run;

/*print macro variables to the to log*/
%put NOTE: runasofdate=&runasofdate | rundate=&rundate. | ora_rundate=&ora_rundate.;
%put NOTE: core_dbflavor=&core_dbflavor.;

/************************************************ build ctr financial item object ************************************************/
proc sql noprint;
connect to &dbflavor. as &dbflavor. (&COREDBCONNOPTS);
create table &worklib..ctr_fin_tmp as 
select *
from connection to &dbflavor. (
select distinct
    c.ctr_id,
    c.transaction_key,
    c.transaction_type_key,
    acc.account_number,
    acc.account_name,
    acc.account_tax_id,
    ceil(cfa.currency_amount) as currency_amount,
    b.branch_number,
    b.branch_name,
    t.transaction_reference_number,
    p.party_name,
    p.doing_business_as_name,
    p.party_tax_id,
    ad.address_line_1_text,
    ad.address_line_2_text,
    ad.city_name,
    ad.state_code,
    ad.postal_code,
    ad.country_code,
    'Y' as include_in_summary
from &core_db..alert_ctr_final c
inner join &core_db..fsc_cash_flow_fact cfa
    on c.transaction_key=cfa.transaction_key
inner join &core_db..fsc_account_dim acc
    on cfa.account_key=acc.account_key
inner join &core_db..fsc_branch_dim b
    on cfa.branch_key=b.branch_key
inner join &core_db..fsc_transaction_dim t
    on cfa.transaction_key=t.transaction_key
inner join &core_db..fsc_party_account_bridge pab
    on acc.account_number=pab.account_number and pab.role_key=1
inner join &core_db..fsc_party_dim p 
    on pab.party_number=p.party_number
left join &core_db..fsc_address_dim ad
    on p.party_number=ad.primary_entity_number and ad.primary_entity_level_code='PTY' and ad.change_current_ind='Y'
where 
	pab.change_begin_date <= cfa.transaction_dttm and
	cfa.transaction_dttm < pab.change_end_date
order by c.ctr_id,c.transaction_type_key
);
disconnect from &dbflavor.;
quit;

/*get summary types*/
proc sql noprint;
create table &worklib..ctr_fin as 
select distinct
    cf.*,
    input(strip(prli.value),8.) as summary_type_code,
    strip(prli.description) as summary_type,
	strip(prli.additional_text) as summary_type_other_desc
from &worklib..ctr_fin_tmp cf
inner join fdhdata.fdx_reference_list_item prli
    on cf.transaction_type_key=input(prli.name,8.)
inner join fdhdata.fdx_reference_list prl
    on prli.fdx_reference_list_id=prl.fdx_reference_list_id
where prl.list_name='CTR Summary Types'
order by ctr_id,summary_type_code
;quit;



/************************************************ create cash transaction investigation (3a) object ************************************************/
data &worklib..ctr_tmp (keep = 
    ctr_id 
    summary_type_code 
    summary_type
	in_total
	out_total
    in_deposit
    in_payment
    in_funds_out
    in_neg_inst
    in_curr_exch
    in_prepaid
    in_gaming_inst
    in_wagers
    in_gaming_devices
    in_other
	in_other_desc
    out_withdrawal
    out_advances
    out_fund_transfer
    out_neg_inst
    out_curr_exch
    out_prepaid
    out_gaming_inst
    out_wagers
    out_travel_exp
    out_contests
    out_other
	out_other_desc
	filing_type
	transaction_date
	transaction_type
    );
set &worklib..ctr_fin;
by ctr_id summary_type_code;
format transaction_date date9.;

retain cash_sum;

if first.ctr_id and first.summary_type_code then do;
    cash_sum=0;
end;

cash_sum=sum(cash_sum,currency_amount);

if summary_type_code=1000 then in_deposit=cash_sum;
if summary_type_code=1001 then in_payment=cash_sum;
if summary_type_code=1002 then in_funds_out=cash_sum;
if summary_type_code=1003 then in_neg_inst=cash_sum;
if summary_type_code=1004 then in_curr_exch=cash_sum;
if summary_type_code=1005 then in_prepaid=cash_sum;
if summary_type_code=1006 then in_gaming_inst=cash_sum;
if summary_type_code=1007 then in_wagers=cash_sum;
if summary_type_code=1008 then in_gaming_devices=cash_sum;
if summary_type_code=1009 then do;
	in_other=cash_sum;
	in_other_desc=summary_type_other_desc;
end;

if summary_type_code=2000 then out_withdrawal=cash_sum;
if summary_type_code=2001 then out_advances=cash_sum;
if summary_type_code=2002 then out_fund_transfer=cash_sum;
if summary_type_code=2003 then out_neg_inst=cash_sum;
if summary_type_code=2004 then out_curr_exch=cash_sum;
if summary_type_code=2005 then out_prepaid=cash_sum;
if summary_type_code=2006 then out_gaming_inst=cash_sum;
if summary_type_code=2007 then out_wagers=cash_sum;
if summary_type_code=2008 then out_travel_exp=cash_sum;
if summary_type_code=2009 then out_contests=cash_sum;
if summary_type_code=2010 then do;
	out_other=cash_sum;
	out_other_desc=summary_type_other_desc;
end;

in_total=sum(in_deposit,
    in_payment,
    in_funds_out,
    in_neg_inst,
    in_curr_exch,
    in_prepaid,
    in_gaming_inst,
    in_wagers,
    in_gaming_devices,
    in_other);

out_total=sum(out_withdrawal,
    out_advances,
    out_fund_transfer,
    out_neg_inst,
    out_curr_exch,
    out_prepaid,
    out_gaming_inst,
    out_wagers,
    out_travel_exp,
    out_contests,
    out_other);

filing_type='A';
transaction_date=input(&ora_rundate.,date9.);
transaction_type='';

if last.ctr_id and last.summary_type_code then output;

run;


/************************************************ validate ctr records for straight through processing ************************************************/
data &worklib..ctr_3a_fails;
set &worklib..ctr_tmp;
length failure_message $50.;
/*transaction_date*/
	failure_message="Invalid TRANSACTION_DATE";
	if transaction_date < datepart("&rundate."dt) or transaction_date > datepart("&rundate."dt) or transaction_date = . then output;
/*total cash in / total cash out*/
	failure_message="IN_TOTAL and OUT_TOTAL < $10,000";
	if coalesce(in_total,0) < 10000 and coalesce(out_total,0) < 10000 then output;
/*values are non-negative*/
	failure_message="Negative value in cash amount field(s)";
	if coalesce(in_total,0) < 0 then output;
	if coalesce(out_total,0) < 0 then output;
	if coalesce(in_deposit,0) < 0 then output;
	if coalesce(in_payment,0) < 0 then output;
	if coalesce(in_funds_out,0) < 0 then output;
	if coalesce(in_neg_inst,0) < 0 then output;
	if coalesce(in_curr_exch,0) < 0 then output;
	if coalesce(in_prepaid,0) < 0 then output;
	if coalesce(in_gaming_inst,0) < 0 then output;
	if coalesce(in_wagers,0) < 0 then output;
	if coalesce(in_gaming_devices,0) < 0 then output;
	if coalesce(in_other,0) < 0 then output;
	if coalesce(out_withdrawal,0) < 0 then output;
	if coalesce(out_advances,0) < 0 then output;
	if coalesce(out_fund_transfer,0) < 0 then output;
	if coalesce(out_neg_inst,0) < 0 then output;
	if coalesce(out_curr_exch,0) < 0 then output;
	if coalesce(out_prepaid,0) < 0 then output;
	if coalesce(out_gaming_inst,0) < 0 then output;
	if coalesce(out_wagers,0) < 0 then output;
	if coalesce(out_travel_exp,0) < 0 then output;
	if coalesce(out_contests,0) < 0 then output;
	if coalesce(out_other,0) < 0 then output; 
/*other descriptions must be populated when in_other/out_other > 0*/
	failure_message="Missing IN_OTHER_DESC/OUT_OTHER_DESC";
	if in_other > 0 and missing(strip(in_other_desc)) then output;
	if out_other > 0 and missing(strip(out_other_desc)) then output;
/*sums must match*/
	failure_message="sum(IN_*) ne IN_TOTAL / sum(OUT_*) ne OUT_TOTAL";
	if in_total > 0 
		and in_total ne sum(in_deposit,in_payment,in_funds_out,in_neg_inst,in_curr_exch,in_prepaid,in_gaming_inst,in_wagers,in_gaming_devices,in_other)
		then output;
	if out_total > 0
		and out_total ne sum(out_withdrawal,out_advances,out_fund_transfer,out_neg_inst,out_curr_exch,out_prepaid,out_gaming_inst,out_wagers,out_travel_exp,out_contests,out_other)
		then output;
run;

proc sql noprint;
create table &worklib..ctr_final as 
select distinct
pass.*,
case 
	when inv.ctr_id is null then 'Y'
	else 'N'
  end as pass_through_ind,
monotonic() as row
from &worklib..ctr_tmp pass
left join &worklib..ctr_3a_fails inv
	on pass.ctr_id=inv.ctr_id
;quit;


/************************************************ create cash transaction investigation object ***********************************************/

/*get count of ctrs to create*/
proc sql noprint;
select count(*)
into: ctr_count
from &worklib..ctr_final
;quit;
%put NOTE: Number of cash transaction investigations to create is ctr_count = &ctr_count.;

%let ctr_count=2;
%do i=1 %to &ctr_count.;

	/*get parent ctr record*/
	data ctr_record;
	set &worklib..ctr_final;
	ordinal=1;
	if row=&i then output;
	run;

	/*transpose parent ctr record*/
	%fdx_ent_transpose(in_ds=ctr_record,out_ds=vi_ctr_record,object_type=tm_cases,child=N,debug=N);

	/*create json payload for parent ctr record*/
	%fdx_write_json_values(table_nm=vi_ctr_record,object_type=fdx_ctr,fileref=json_out,create=Y,debug=Y);

%end;




	


/************************************************ relate case to entities (party, external party, account) ************************************************/



%exit:

%put NOTE: {END: FDX_CTI_CREATE PROGRAM};

%mend fdx_ctr_create;

%fdx_ctr_create
