/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Execute Web Service GET request to retrieve current document and store info
/                in a modifiable SAS Dataset
/ DESCRIPTION  : This macro executes a web service GET request for the supplied object_type and id.
/                It returns a table specified in the out_ds parameter storing 3 fields: COLUMN_NAME,
/                DATA_TYPE, and VALUE. Each field value from the GET request will be transposed, and
/                its corresponding data type will also be included. Users can then modify the table
/                and pass it to the fdx_write_json_values macro to create an updated request payload
/                which can then be used in a PUT statement to update the object.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ object_type         doc type (table name in fdhdata)
/ object_id           unique identifier for the doc type
/ object_key          name of field that is unique identifier for doc type
/ out_ds              out data set that can then be modified
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_get_json_values(object_type=crrrvw,
/                                 object_id=%str(CRR - 10000),
/                                 object_key=crrrvw_id,
/                                 out_ds=crrrvw_fields);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_get_json_values(object_type=,object_id=,object_key=,out_ds=,debug=N);

%fdx_ws_get_doc_json(object_type=&object_type, object_id=&object_id,debug=&debug.);
libname json_in json fileref=ws_out;
proc sql noprint;
select strip(objectTypeName),objectTypeId,objectTypeVersion,strip(id)
into :objectTypeName,:objectTypeId,:objectTypeVersion,:id
from json_in.root
;quit;

proc sql noprint;
create table work.fieldvalues as 
select *
from fdhdata.&object_type
where &object_key = "&object_id"
;quit;


proc sql noprint;
connect to &dbflavor. as &dbflavor. (&pgConnOpts.);
create table &object_type._mx as 
select *
from connection to &dbflavor. (
select column_name,data_type
from information_schema.columns
where table_schema='fdhdata' and table_name=%bquote(')&object_type.%bquote(') 
);
disconnect from &dbflavor.;
;quit;

proc sql noprint;
select column_name into :columns separated by ' ' from &object_type._mx;
quit;

proc transpose data=fieldvalues out=tran_fieldvalues (rename=(_name_=name col1=value)) ;
var &columns;
run;

proc sql noprint;
create table &object_type.nms as
select f.field_nm,f.column_nm from fdhmeta.dh_stored_field f
inner join fdhmeta.dh_stored_object o
on o.stored_object_id=f.stored_object_id
where o.object_nm="&object_type.";
quit;

proc sql noprint;
create table &object_type._vd as 
select 
	n.field_nm as column_name,
	v.value,
	d.data_type
from tran_fieldvalues v
inner join &object_type._mx d
	on (lowcase(v.name) = lowcase(d.column_name))
inner join &object_type.nms n 
	on (lowcase(v.name) = lowcase(n.column_nm))


where v.name ne "_ID_NUMERIC_PART_NO_"
;quit;


data &out_ds;
set &object_type._vd;
length new_month $2 month $3 new_date $30 date_num 8;
ordinal=1;
value=strip(value);

if ( data_type = "timestamp without time zone") 
  and value ne "." 
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

if ( data_type = "timestamp with time zone")
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

if ( data_type = "timestamp without time zone") 
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

if data_type = "date" and not missing(value) and strip(value) ne "." then do;
date_num=input(strip(value),anydtdte10.);
new_date=put(date_num,yymmdd10.);
month=substr(new_date,3,3);
value=cats(new_date , 'T00:00:00.000Z');
end;

drop new_month month date_num new_date;
if column_name ne '_ID_NUMERIC_PART_NO' then output;
run;
proc contents noprint data=json_in._all_ out=json_meta;run;

proc sql noprint;
create table json_child_table_xref as select o.object_nm,
cats(upcase(substr(o.object_nm,1,18)),'_FIELDVALUES') as json_tbl_nm 
from fdhmeta.dh_object_relationship r
	inner join fdhmeta.dh_stored_object o
		on o.stored_object_id=r.to_stored_object_id
	where r.relationship_type_cd='DIRECT_CHILD'
	and r.from_stored_object_id=&objectTypeId
	and cats(upcase(substr(o.object_nm,1,18)),'_FIELDVALUES') in	
		(select memname from json_meta) ;
quit;
proc sql noprint;
select count(*) into :child_tbl_cnt from json_child_table_xref;
quit;

%put NOTE: child_tbl_cnt is &child_tbl_cnt;
%if &child_tbl_cnt eq 0 %then %goto MACRO_END;
proc sql noprint;
select object_nm,json_tbl_nm into :obj_nm1-:obj_nm%trim(&child_tbl_cnt),:json_tbl1-:json_tbl%trim(&child_tbl_cnt) from json_child_table_xref;
quit;

%put NOTE: obj_nm1 is &obj_nm1;
%macro children_transpose;
/* Loop through child tables and transpose */
%do j=1 %to &child_tbl_cnt.;
	%if %sysfunc(exist(json_in.&&json_tbl&j.)) %then %do;

		data &&json_tbl&j.;
		set json_in.&&json_tbl&j.;
		ordinal=1;
		run;

		proc contents noprint data=&&json_tbl&j. out=&&obj_nm&j..md;run;

		proc sql noprint;
		connect to &dbflavor. as &dbflavor. (&pgConnOpts.);
		create table &&obj_nm&j.._md1 as 
		select *
		from connection to &dbflavor. (
			select column_name,data_type
			from information_schema.columns
			where table_schema='fdhdata' and table_name=%bquote(')&&obj_nm&j.%bquote(') 
		);
		disconnect from &dbflavor.;
		;quit;

		proc sql noprint;
		create table &&obj_nm&j.._mx as
		select * from &&obj_nm&j.._md1
		where upcase(column_name) in (select upcase(name) from &&obj_nm&j..md);
		quit;
		
		proc sql noprint;
		select column_name into :columns separated by ' ' from &&obj_nm&j.._mx;
		quit;
		
		proc transpose data=&&json_tbl&j. out=tran_&&obj_nm&j. (rename=(_name_=name col1=value)) ;
		by ordinal ordinal_fieldvalues;
		var &columns;
		run;

		proc sql noprint;
		create table &&obj_nm&j.._vd as 
		select 
			v.ordinal,
			v.ordinal_fieldvalues,
			v.name as column_name,
			v.value,
			d.data_type
		from tran_&&obj_nm&j. v
		inner join &&obj_nm&j.._mx d
			on (v.name = d.column_name)
		order by ordinal,ordinal_fieldvalues,column_name
		;quit;

		data &&json_tbl&j.;
		set &&obj_nm&j.._vd;
		length new_month $2 month $3 new_date $30 date_num 8;
		ordinal=1;
		value=strip(value);
		
		if ( data_type = "timestamp without time zone" ) 
		  and value ne "." 
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
		  and value ne "." 
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
		  and value ne "." 
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
		  and value ne "." 
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
		
		if data_type = "date" and not missing(value) and strip(value) ne "." then do;
		date_num=input(strip(value),anydtdte10.);
		new_date=put(date_num,yymmdd10.);
		month=substr(new_date,3,3);
		value=cats(new_date , 'T00:00:00.000Z');
		end;
		drop new_month month date_num new_date;
		if column_name ne '_ID_NUMERIC_PART_NO' then output;
		run;

	%end; /* end of if exists */
%end; /*end of loop*/
%mend;
%children_transpose;
%MACRO_END:
%mend;

