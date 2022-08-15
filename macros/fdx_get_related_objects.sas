/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Pete Ferrera (pete.ferrera@sas.com)
/ PURPOSE      : Execute Web Service POST request to retrieve related document ids
/ DESCRIPTION  : This macro executes a web service POST request for the supplied object_type, object_id, and 
/                related_object_type.  It returns a table specified in the out_ds parameter storing 1 field: 
/                OBJECT_ID that will contain the object_id(s) of all related objects for the supplied 
/                related_object_type.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ object_type         doc type (table name in fdhdata)
/ object_id           unique identifier for the doc type
/ related_object_type doc type of related object
/ out_ds              out data set that can then be modified
/ use_api             Y = safe but bad performance
/                     N = use tables for better performance, but may not handle all relationship
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_get_related_objects(object_type=rr_report,
/                                     object_id=%str(10000),
/                                     related_object_type=rr_sar_report
/                                     out_ds=sar_report_ids);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_get_related_objects(object_type=,object_id=,related_object_type=,out_ds=,use_api=Y);

%if &use_api eq N %then %do;
proc sql noprint;

SELECT 
    r.table_nm,
	scan(translate(join_condition_1_txt,'     ','"{:,}'),17),
	scan(translate(join_condition_2_txt,'     ','"{:,}'),9) 
	into
	:r_table_nm,
	:from_fld,
	:to_fld trimmed
from fdhmeta.dh_object_relationship r
inner join fdhmeta.dh_stored_object t on t.stored_object_id=r.to_stored_object_id
inner join fdhmeta.dh_stored_object f on f.stored_object_id=r.from_stored_object_id
where f.object_nm="&object_type" and t.object_nm="&related_object_type";
%let nobs=&sqlobs;
quit;

%put NOTE: nobs is &nobs, r_table_nm is &r_table_nm, from_fld is &from_fld, to_fld is &to_fld;

proc sql noprint;
create table &out_ds as select &to_fld as object_id from fdhdata.&r_table_nm where &from_fld = "&object_id";
quit;
%end;
%else %do;
filename rel_req "%sysfunc(pathname(work))/updated_&object_type._&object_id._&related_object_type._.json";
filename ws_out "%sysfunc(pathname(work))/traversal_out.json";

proc json out=rel_req pretty nosastags;
	write values "edgeTypes";
		write open array;
			write values "document_link";
		write close; /*edgeTypes array*/
	write values "query";
		write open object;
			write values "type" "documents";
			write values "docs";
				write open array;
					write open object;
						write values "type" "&object_type";
						write values "id" "&object_id";
					write close; /*docs object*/
				write close; /*docs array*/
		write close; /*query object*/
	write values "depth" 1;
	write values "vertexFilter";
		write open object;
			write values "type" "type";
			write values "types";
				write open array;
					write values "related_object_type" "&related_object_type";
				write close; /* types array */
		write close; /* vertexFilter object */
	write values "extendedFormat" true;
run;

%global ws_http_code;
%let ws_http_code=0;
%fdx_ws_http_post_json(
      url=svi-sand/rest/traversals, 
      ws_in_json_fref=rel_req,
      _ws_out_json_fref=ws_out,
      _ws_http_code=ws_http_code
    );
 
    %put NOTE: SYS_PROCHTTP_STATUS_CODE is &SYS_PROCHTTP_STATUS_CODE;
    %if &SYS_PROCHTTP_STATUS_CODE ne 201 and &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 206 %then %do;
      %put ERROR: Failed to execute POST request to get relationships;
    %end;

libname jresp json fileref=ws_out;

proc sql noprint;
select vertices into:vcnt from jresp.counts;
quit;

%if &vcnt eq 0 %then %do;
	data &out_ds;
	length object_id $50;
	stop;
	run;
%goto END_GET_REL;
%end;

proc sql noprint;
create table &out_ds as select id as object_id from jresp.vertices
where type="&related_object_type";
;quit;
%end;
%END_GET_REL:

%mend;

