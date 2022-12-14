/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : API utility function that takes a SAS dataset as input and returns a JSON payload
/ DESCRIPTION  : This macro executes a PROC JSON to create a request payload for an HTTP call. It requires
/                macro variables that are generated by the fdx_get_json_values macro program. The input table
/                must have the same format as the output table (out_ds parameter)from the fdx_get_json_values
/                macro program.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ table_nm            table with updated field values
/ object_type         doc type (table name in fdhdata)
/ object_id           unique identifier for the doc type
/ fileref             fileref pointing to json output to then pass as request payload (will always be in work location)
/ child_xref_ds       table that includes list of child objects and tables created by json import
/                     default is json_child_table_xref
/ create              determines whether the payload will be for a new object record
/                     default is N
/ debug               determines whether or not to print helpful debugging information to the log
/                     default is N
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_write_json_values(table_nm=updated_crrrvw,
/                                   object_type=crrrvw,
/                                   object_id=%str(CRR - 10000),
/                                   fileref=json_out);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_write_json_values(table_nm=,object_type=,object_id=,fileref=json_out,child_xref_ds=json_child_table_xref,create=N,debug=N);

%if &create eq N %then %do;
filename &fileref "/home/sasadmin/krmood/util/updated_&object_type.&object_id..json";
%end;
%else %do;
filename &fileref "/home/sasadmin/krmood/util/new_&object_type..json";
%end;	 

/*correct encoding problem with single quote*/
data &table_nm;
set &table_nm;
if data_type="character varying" or data_type="character" then do;
value=tranwrd(value,'E28099'x,"'");
value=tranwrd(value,'e280'x,"'");
value=tranwrd(value,'e2'x,"'");
end;
run;

/* Get main field values */
proc sql noprint;
select count(*) into :json_values_count from &table_nm;
select column_name,data_type,value
into :column_name1 - :column_name%trim(&json_values_count.) , :data_type1 - :data_type%trim(&json_values_count.) , :value1 - :value%trim(&json_values_count.) 
from &table_nm;
quit;

proc sql noprint;
select object_nm,stored_object_id,optlock_version_no
	into :objectTypeName,:objectTypeId,:objectTypeVersion
	from fdhmeta.dh_stored_object where object_nm="&object_type.";
quit;

/* get child table info into macro vars */
%let child_tbl_cnt=0;
%if %sysfunc(exist(&child_xref_ds)) %then %do;
proc sql noprint;
select count(*) into :child_tbl_cnt from &child_xref_ds;
quit;
%end;
%put NOTE: child_tbl_cnt is &child_tbl_cnt;

%if &child_tbl_cnt gt 0 %then %do;
	proc sql noprint;
	select object_nm,json_tbl_nm into :obj_nm1-:obj_nm%trim(&child_tbl_cnt),:json_tbl1-:json_tbl%trim(&child_tbl_cnt) from &child_xref_ds;
	quit;
%end;

%do j=1 %to &child_tbl_cnt.;

proc sql noprint;
select stored_object_id, optlock_version_no into :&&obj_nm&j..id, :&&obj_nm&j..ver
from fdhmeta.dh_stored_object
where upcase(table_nm) = upcase("&&obj_nm&j..");
quit;
%let ver=%trim(&&obj_nm&j..ver);
%PUT NOTE:  child objectTypeVersion is &&obj_nm&j..ver = &&&ver;
%let tid=%trim(&&obj_nm&j..id);
%PUT NOTE: child objectTypeID is &&obj_nm&j..id = &&&tid;

proc sql noprint;
select count(*) into :&&obj_nm&j.._cnt from &&json_tbl&j.;
quit;
%let cnt=&&obj_nm&j.._cnt;
%put NOTE: Number of records to process from child object &j. is &&obj_nm&j.._cnt = &&&cnt.;

/*correct encoding problem with single quote*/
data &&json_tbl&j.;
set &&json_tbl&j.;
if data_type="character varying" or data_type="character" then do;
value=tranwrd(value,'E28099'x,"'");
value=tranwrd(value,'e280'x,"'");
value=tranwrd(value,'e2'x,"'");
end;
run;
proc sort data=&&json_tbl&j.;
by ordinal ordinal_fieldvalues column_name;
run;

proc sql noprint;
select ordinal_fieldvalues,column_name,data_type,value 
	into :&&obj_nm&j..o1-:&&obj_nm&j..o%trim(&&&cnt.) ,
		:&&obj_nm&j..n1-:&&obj_nm&j..n%trim(&&&cnt.) ,
		:&&obj_nm&j..d1-:&&obj_nm&j..d%trim(&&&cnt.) ,
		:&&obj_nm&j..v1-:&&obj_nm&j..v%trim(&&&cnt.) 
 from &&json_tbl&j.
;quit;

/*%let ord=&&obj_nm&j..o1;*/
/* %put NOTE: &&obj_nm&j..o1 is &&&ord.; */
/*%let nm=&&obj_nm&j..n1;*/
/* %put NOTE: &&obj_nm&j..n1 is &&&nm.; */
/*%let dt=&&obj_nm&j..d1;*/
/* %put NOTE: &&obj_nm&j..d1 is &&&dt.; */
/*%let val=&&obj_nm&j..v1;*/
/* %put NOTE: &&obj_nm&j..v1 is %superq(&&val.); */
data test;
set &&json_tbl&j.;
by ordinal_fieldvalues;
length varnm $32;
varnm=cat("&&obj_nm&j.._id",ordinal_fieldvalues);
if column_name="&&obj_nm&j.._id" then do;
 call symputx(varnm,value);
 output;
end;
else do;
	if last.ordinal_fieldvalues then do;
	 call symputx(varnm,'');
	 output;
	end;
end;
run;
%if &create eq N %then %do;
	data &&obj_nm&j.._ids;
	set &&json_tbl&j..;
	length varnm $32.;
	by ordinal_fieldvalues;
	varnm=cat("&&obj_nm&j.._id",ordinal_fieldvalues);
	if column_name="&&obj_nm&j.._id" then output;
	run;
	proc sql noprint;
	select count(*) into: m_cnt from &&obj_nm&j.._ids;
	quit;
	%put NOTE: Number of records for child object &&json_tbl&j.. is &m_cnt.;
	%do m=1 %to &m_cnt.;
	data &&obj_nm&j.._pks_&m.;
	set &&obj_nm&j.._ids;
	if varnm="&&obj_nm&j.._id&m" then output;
/*	call symputx("obj&j._pk_&m.",value);*/
	run;
	proc sql noprint;
	select value into :&&obj_nm&j.._id&m. from &&obj_nm&j.._pks_&m.
	;quit;
	%end; /*end m=1 to m_cnt*/
	%put NOTE: child object primary key field is &&obj_nm&j.._id;
	%let objid = &&obj_nm&j.._id;
	%put NOTE: child object primary key field is &&obj_nm&j.._id = &objid;
	%let aaa=&&obj_nm&j.._id1;
	%put NOTE: &&obj_nm&j.._id primey key value is &&&aaa;
%end; /*if create eq N*/

%end; /*end j=1 to child_tbl_cnt. loop*/

proc json out=&fileref pretty nosastags;
write values "objectTypeId" &objectTypeId.;
%if %length(&object_id) gt 0 %then %do;
    write values "objectTypeName" "&objectTypeName.";
	write values "id" "&object_id.";
	write values "objectTypeVersion" &objectTypeVersion;
%end;
write values "fieldValues";
write open object;
	%do k=1 %to &json_values_count.;
		%if "%superq(value&k.)" ne "" and "%superq(value&k.)" ne "." %then %do;
			
				%if "&&data_type&k" = "boolean" %then %do;
					%if &&value&k = 1 %then %do;
						write values "&&column_name&k." true;
					%end;
					%if &&value&k = 0 %then %do;
						write values "&&column_name&k." false;
					%end;
				%end;
				%if "&&data_type&k" = "character varying" or "&&data_type&k" = "character" %then %do;
					write values "&&column_name&k." "%superq(value&k.)";
				%end;
				%if "&&data_type&k" = "integer" or "&&data_type&k" = "bigint" or "&&data_type&k" = "numeric" or "&&data_type&k" = "double precision" or "&&data_type&k" = "smallint" %then %do;
					write values "&&column_name&k." &&value&k.;
				%end;
				%if "&&data_type&k" = "timestamp without time zone" %then %do;
					write values "&&column_name&k." "&&value&k.";
				%end;
				%if "&&data_type&k" = "timestamp with time zone" %then %do;
					write values "&&column_name&k." "&&value&k.";
				%end;
				%if "&&data_type&k" = "date" %then %do;
					write values "&&column_name&k." "&&value&k.";
				%end;
			
		%end; /*end of if condition to check if field value is null*/
	%end; /*end of k=1 to json_values_count loop*/
	%put NOTE: >>>> END OF DO LOOP TO CREATE JSON FIELD VALUES <<<<<;
	%put NOTE: >>>> BEGIN DO LOOP TO CREATE CHILD OBJECT JSON FIELDS <<<<;
	%put NOTE: child_tbl_cnt = &child_tbl_cnt. ;
	%do child_i=1 %to &child_tbl_cnt.; 
		write values "&&obj_nm&child_i.";
		write open array;
		write open object;
		%let tid=%trim(&&obj_nm&child_i..id);
		write values "objectTypeId" &&&tid.;
		%if &create eq N %then %do;
			write values "objectTypeName" "&&obj_nm&child_i.";
			%let ver=%trim(&&obj_nm&child_i..ver);
			/* %PUT NOTE:  &&obj_nm&child_i..ver is &&&ver; */
			write values "objectTypeVersion" &&&ver.;	

			%let objid_first=&&obj_nm&child_i.._id1;	
			/* %put NOTE: &&obj_nm&child_i.._id primey key value is &&&objid_first;			 */
			%if %length(&&&objid_first.) gt 0 %then %do;
				write values "id" "&&&objid_first.";
			%end;
		%end;
		write values "fieldValues";
		write open object;
		%let prev_ord=1;
		%let cnt=&&obj_nm&child_i.._cnt;
		/* %put NOTE: &&obj_nm&child_i.._cnt is &&&cnt.; */
		%do lp=1 %to &&&cnt.;
			%let obj=&&obj_nm&child_i.;
			 %put NOTE:obj is &obj; 
			%let ord=&&obj.o&lp.;
			 %put NOTE: &ord is &&&ord.; 
			%let nm=&&obj.n&lp;
			 %put NOTE: &nm is &&&nm.; 
			%let dt=&&obj.d&lp;
			 %put NOTE: &dt is &&&dt.; 
			%let val=&&obj.v&lp;
			%put NOTE: &val is %superq(&&val.); 
			%if &&&ord. ne &prev_ord %then %do;
				write close;
					%if &create eq Y %then %do;
					write values "isNew" true;
					%end; /*end if create eq Y*/
				write close;
				write open object;		
				%let tid=%trim(&&obj_nm&child_i..id);
				write values "objectTypeId" &&&tid.;
				%if &create eq N %then %do;
					write values "objectTypeName" "&&obj_nm&child_i.";
					%let ver=%trim(&&obj_nm&child_i..ver);
					/* %PUT NOTE:  &&obj_nm&child_i..ver is &&&ver; */
					write values "objectTypeVersion" &&&ver.;
					%let objid = &&obj._id&&&ord;
					/* %put NOTE: &obj._id&&&ord is &&&objid; */
					%if %length(&&&objid.) gt 0 %then %do;
						write values "id" "&&&objid.";
					%end; /*end if length(objid) gt 0*/
				%end; /*end if create eq N*/
				%let prev_ord=&&&ord.;
				write values "fieldValues";
				write open object;		
			%end; 						
			%if "%superq(&&val.)" ne "" and "%superq(&&val.)" ne "." and "%superq(&&val.)" ne "--.TZ" %then %do;
				
					%if "&&&dt." = "boolean" %then %do;
						%if &&&val. = 1 %then %do;
							write values "&&&nm." true;
						%end;
						%else %do;
							write values "&&&nm." false;
						%end;
					%end; /*end if dt eq boolean*/
					%if "&&&dt." = "character varying" or "&&&dt." = "character" %then %do;
						
						/*the following condition is not needed per PUB-1125*/
						/*%if &&&nm. ne &objid. and &create. eq Y %then %do;*/
						write values "&&&nm." "%superq(&&val.)";

					%end; /*end if dt eq character or character varying*/
					%if "&&&dt." = "integer" or "&&&dt." = "bigint" or "&&&dt." = "numeric" or "&&&dt." = "double precision" %then %do;
						write values "&&&nm." &&&val.;
					%end; /*end if dt is numeric*/
					%if "&&&dt." = "timestamp without time zone" %then %do;
						write values "&&&nm." "&&&val.";
					%end; /*end if dt eq timestamp without time zone*/
					%if "&&&dt." = "timestamp with time zone" %then %do;
						write values "&&&nm." "&&&val.";
					%end; /*end if dt eq timestamp with timezone*/
					%if "&&&dt." = "date" %then %do;
						write values "&&&nm." "&&&val.";
					%end; /*end if dt eq date*/
			%end; /*end of if condition to check if field value is null*/
		%end; /*child lp=1 to cnt loop*/
		write close;/*close child fieldvalues*/
		%if &create eq Y %then %do;
		write values "isNew" true;
		%end; /*end if create = Y*/
		write close;/*close child object*/
		write close; /*close child table array*/

	%end; /*end do=1 to cnt loop*/
write close;/*end document*/
run;


/*print json to log if debug = Y*/
%if &debug eq Y %then %do;
data _null_;
  infile &fileref lrecl=32767;
  input;
  put "DEBUG: > " _infile_;
run;
%end; /*end if debug eq Y*/

%mend;
