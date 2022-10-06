/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Pete Ferrera (pete.ferrera@sas.com) & Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Transpose ds for writing json and map vi field names to column metadata
/ DESCRIPTION  : This program transposes SAS datasets to into the format expected by the fdx_write_json_values.sas
/                so that it can be turned into a JSON payload for API requests.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ in_ds               dataset you want to transpose
/ out_ds              transposed dataset
/ object_type         document type
/ by_var              field in in_ds to tranpose by
/ child               indicator for if the object is a child object
/ debug               indicator for printing additional info to log
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_ent_transpose(in_ds=,
/                               out_ds=,
/                               object_type=,
/                               by_var=case_id,
/                               child=N,
/                               debug=N);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_ent_transpose(in_ds=,out_ds=,object_type=,by_var=case_id,child=N,debug=N);

proc sql noprint;
connect to &pgDBFlavor. as &pgDBFlavor. (authDomain="&pgDBAuth." &pgConnOpts.);
create table &object_type.mdz as 
select *
from connection to &pgDBFlavor. (
select column_name,data_type
from information_schema.columns
where table_schema='fdhdata' and table_name=%bquote(')&object_type.%bquote(') 
);
disconnect from &pgDBFlavor.;
;quit;

proc sql noprint;
create table &object_type.nms as
select f.field_nm,f.column_nm from fdhmeta.dh_stored_field f
inner join fdhmeta.dh_stored_object o
on o.stored_object_id=f.stored_object_id
where o.object_nm="&object_type.";
quit;

proc contents noprint data=&in_ds out=&object_type.md2;run;
proc sql noprint;
select field_nm into :columns separated by ' ' from &object_type.nms 
	where upcase(strip(field_nm)) in (select upcase(strip(name))as column_name from &object_type.md2) ;
quit;

%put NOTE:columns is &columns;

proc transpose data=&in_ds out=tran_fieldvalues (rename=(_name_=name col1=value)) ;
by ordinal 
%if &child=Y %then %do;
ordinal_fieldvalues
%end;
;
var &columns;
run;

proc sql noprint;
create table &object_type._vd as 
select 
	ordinal,
	%if &child=Y %then %do;
	ordinal_fieldvalues,
	%end;
	n.field_nm as column_name,
	strip(v.value) as value,
	d.data_type
from tran_fieldvalues v
inner join &object_type.nms n 
	on (lowcase(v.name) = lowcase(n.field_nm))
inner join &object_type.mdz d
	on (lowcase(n.column_nm) = lowcase(d.column_name))

where v.name ne "_ID_NUMERIC_PART_NO_"
;quit;

data &out_ds;
set &object_type._vd;
length new_month $2 month $3;
value=strip(value);
put _all_;

if ( data_type = "timestamp without time zone" )
	and strip(value) ne "." and not missing(value)
  and length(value) > 20 
  then do;
month=substr(value,3,3);
if month="JAN" then new_month="01";
else if month="FEB" then new_month="02";
else if month="MAR" then new_month="03";
else if month="APR" then new_month="04";
else if month="MAY" then new_month="05";
else if month="JUN" then new_month="06";
else if month="JUL" then new_month="07";
else if month="AUG" then new_month="08";
else if month="SEP" then new_month="09";
else if month="OCT" then new_month="10";
else if month="NOV" then new_month="11";
else if month="DEC" then new_month="12";
value=cats(substr(value,6,4), '-', new_month, '-', substr(value,1,2) , 'T', substr(value,11,12), 'Z');
end;

if ( data_type = "timestamp with time zone" )
	and strip(value) ne "." and not missing(value)
  and length(value) > 20 
  then do;
month=substr(value,3,3);
if month="JAN" then new_month="01";
else if month="FEB" then new_month="02";
else if month="MAR" then new_month="03";
else if month="APR" then new_month="04";
else if month="MAY" then new_month="05";
else if month="JUN" then new_month="06";
else if month="JUL" then new_month="07";
else if month="AUG" then new_month="08";
else if month="SEP" then new_month="09";
else if month="OCT" then new_month="10";
else if month="NOV" then new_month="11";
else if month="DEC" then new_month="12";
value=cats(substr(value,6,4), '-', new_month, '-', substr(value,1,2) , 'T', substr(value,11,12), cats(strip(put(tzoneoff()/3600,z3.)),':00'));
end;

if ( data_type = "timestamp without time zone" ) 
  and value ne "." and not missing(value)
  and length(value) <= 20 
then do;
date_num=input(value,anydtdtm22.);
new_date=put(date_num,datetime22.);
new_date=strip(new_date);
month=substr(new_date,3,3);
if month="JAN" then new_month="01";
else if month="FEB" then new_month="02";
else if month="MAR" then new_month="03";
else if month="APR" then new_month="04";
else if month="MAY" then new_month="05";
else if month="JUN" then new_month="06";
else if month="JUL" then new_month="07";
else if month="AUG" then new_month="08";
else if month="SEP" then new_month="09";
else if month="OCT" then new_month="10";
else if month="NOV" then new_month="11";
else if month="DEC" then new_month="12";
value=cats(substr(new_date,6,4), '-', new_month, '-', substr(new_date,1,2) , 'T', substr(new_date,11,12), 'Z');
end;

if ( data_type = "timestamp with time zone") 
  and value ne "." and not missing(value)
  and length(value) <= 20 
then do;
date_num=input(value,anydtdtm22.);
new_date=put(date_num,datetime22.);
new_date=strip(new_date);
month=substr(new_date,3,3);
if month="JAN" then new_month="01";
else if month="FEB" then new_month="02";
else if month="MAR" then new_month="03";
else if month="APR" then new_month="04";
else if month="MAY" then new_month="05";
else if month="JUN" then new_month="06";
else if month="JUL" then new_month="07";
else if month="AUG" then new_month="08";
else if month="SEP" then new_month="09";
else if month="OCT" then new_month="10";
else if month="NOV" then new_month="11";
else if month="DEC" then new_month="12";
value=cats(substr(new_date,6,4), '-', new_month, '-', substr(new_date,1,2) , 'T', substr(new_date,11,12), cats(strip(put(tzoneoff()/3600,z3.)),':00'));
end;

if ( data_type = "date")
	and strip(value) ne "." and not missing(value)
	then do;
month=substr(value,3,3);
if month="JAN" then new_month="01";
else if month="FEB" then new_month="02";
else if month="MAR" then new_month="03";
else if month="APR" then new_month="04";
else if month="MAY" then new_month="05";
else if month="JUN" then new_month="06";
else if month="JUL" then new_month="07";
else if month="AUG" then new_month="08";
else if month="SEP" then new_month="09";
else if month="OCT" then new_month="10";
else if month="NOV" then new_month="11";
else if month="DEC" then new_month="12";
value=cats(substr(value,6,4), '-', new_month, '-', substr(value,1,2) , 'T00:00:00.000Z');
end;

drop new_month month date_num new_date;
if column_name ne '_ID_NUMERIC_PART_NO' AND not (strip(value)="." AND data_type in ("timestamp without time zone","timestamp with time zone","date")) then output;
run;
%if debug eq Y %then %do;
data _null_;
set &out_ds;
put _all_;
run;
%end;


%mend;
