/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Pete Ferrera (pete.ferrera@sas.com)
/ PURPOSE      : Transpose ds and dump to a single text field
/ DESCRIPTION  : This macro takes a SAS dataset and transposes it into a dataset containing a single
/                character field titled COMMENT_TXT. The contents of the string field can then be
/                fed to the %fdx_add_comment.sas macro to add an HTML formatted table as a comment to a
/                VI object. Users can also provide a title for the table that will appear in the comment.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ in_ds               id of the object to add comment
/ out_ds              type of the object for &object_id
/ tbl_title           message to post in the comment
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fdx_dump_ds_record_to_comment(in_ds=hist_case_data,
/                                         out_ds=case_comment,
/                                         tbl_title=%str(Data for Historical Case XXXXXX)
/                                         );
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_dump_ds_record_to_comment(in_ds=,out_ds=,tbl_title=Data for &in_ds);
proc contents noprint data=&in_ds out=&in_ds.md2;run;
proc sql noprint;
select name into :columns separated by ' ' from &in_ds.md2 
;
quit;

%put NOTE:columns is &columns;

proc transpose data=&in_ds out=&in_ds.trn ;
;
/*by case_rk;*/
var &columns;
run;

data _null_;
set &in_ds.trn ;
put _all_;
run;

data &out_ds (keep=comment_txt);
set &in_ds.trn end=last;
length comment_txt $32760;
retain comment_txt;
value=strip(value);
if _n_=1 then do;
	comment_txt="<h1>&tbl_title</h1><table><tr><th>Field</th><th>Value</th></tr>";
end;
comment_txt=strip(comment_txt)||'<tr><td><span style="color:#0378cd">'||strip(_NAME_)||"</td><td>"||strip(col1)||"</td></tr>";
if last then do;
	comment_txt=strip(comment_txt)||"</table>";
	output;
end;
run;
%mend;

