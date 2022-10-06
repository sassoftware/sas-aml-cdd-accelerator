/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Copy files to another location on the server
/ DESCRIPTION  : This program will copy files on the server to the desired directory. 
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ sdir         source directory location
/ tdir         target directory location
/ sfile_nm     source file name
/ tfile_nm     target file name
/ util_loc     directory location for copy script
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:  %fdx_cp_files(sdir=,
/                         tdir=,
/                         sfile_nm=,
/                         tfile_nm=,
/                         util_loc=
/                         ); 
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_cp_files(sdir=,tdir=,sfile_nm=,tfile_nm=,util_loc=);
%if %length(&tfile_nm) eq 0 %then %do;
	%let tfile_nm=%superq(sfile_nm);
%end;

%if %symexist(proc_num) %then %do;
	%if %length(&proc_num.) eq 0 %then %do;
		%let proc_num=1;
	%end;
%end;
%else %do;
	%let proc_num=1;
%end;
%put NOTE: proc_num = &proc_num.;
	
data _null_;
length lst_chr $1 sfile_nm tfile_nm $1000;
sdir="&sdir.";
sfile_nm="%superq(sfile_nm)";
tfile_nm="%superq(tfile_nm)";
lst_chr=substr(strip(sdir),length(strip(sdir)));
if lst_chr='/' then new_sdir=substr(strip(sdir),1,length(strip(sdir)) - 1);
else new_sdir=strip(sdir);
call symput('new_sdir',strip(new_sdir));
call symput('sfile_nm',strip(sfile_nm));
call symput('tfile_nm',strip(tfile_nm));
run;
%put NOTE: new_sdir is &new_sdir., sfile_nm is %superq(sfile_nm) , tfile_nm is %superq(tfile_nm);
data cp_files;
length fname $255;
sfname="%superq(sfname)";
tfname="%superq(tfname)";
output;
run;

filename cmd_ln "&util_loc./fdx_cp_files_&proc_num._&SYSPROCESSID..bash";
data _null_;
set cp_files;
length copy_line $1000;
file cmd_ln;
copy_line='cp ' || "&new_sdir./" || tranwrd(strip(sfname),' ','\ ')
			 || " &tdir./" 
			|| tranwrd(strip(tfname),' ','\ ');
put copy_line;
put "if [ $? -eq 0 ]";
put "then";
put  'echo "Success"';
put "fi";
run;

%let cp_script=&util_loc./fdx_cp_files_&proc_num._&SYSPROCESSID..bash;
/*change permissions on bash script*/
filename indata pipe "chmod 775 &cp_script"; 
data results; 
  length rline $255; 
  infile indata truncover; /* infile statement for results */ 
  input rline $255.; /* read the results */ 
run;

data _null_;
set results;
put "NOTE: " rline;
run;
filename indata pipe "&cp_script";
%let num_files=0;
data results; 
  length rline $255; 
  infile indata truncover; /* infile statement for results */ 
  input rline $255.; /* read the results */ 
run;


data _null_;
set results;
if strip(lowcase(rline)) = 'success' then do;
	put "NOTE: " rline;
end;
if findw(strip(lowcase(rline)),'no such file or directory')>0 then do;
		put "NOTE: source file not found. cp command output is - " rline;
end;
if findw(strip(lowcase(rline)),'no such file or directory')=0 and strip(lowcase(rline)) ne 'success' then do;
		put "ERROR: " rline;
end;
run;

%mend;

