/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Expand nested alert network
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_get_ref_list_values(list_name=%str(Custom Batch Global Macros));

%put NOTE: {BEGIN: fdx_get_ref_list_values macro};

/*check that provided list exists*/
proc sql noprint;
select 
count(*)
into: list_exists
from fdhdata.fdx_reference_list
where list_name="&list_name."
;quit;

%if &list_exists eq 0 %then %do;
	%put NOTE: list &list_name. does not exist - exiting macro;
	%goto exit;
%end;

proc sql noprint;
create table list_values as 
select 
	c.name,
	c.value
from fdhdata.fdx_reference_list_item c
inner join fdhdata.fdx_reference_list l 
	on c.fdx_reference_list_id=l.fdx_reference_list_id 
where l.list_name="&list_name."
;quit;

data _null_;
set list_values;
call symputx(name,value,'G');
run;

%exit:

%put NOTE: {END: fdx_get_ref_list_values macro};

%mend fdx_get_ref_list_values;
