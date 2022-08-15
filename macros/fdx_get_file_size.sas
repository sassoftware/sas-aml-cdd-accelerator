/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Execute data step to retrieve filesize
/ DESCRIPTION  : This macro executes a data step and retrieves the file size for a file on the server. It
/                returns the filesize to a macro variable with the name defined in the filesize= parameter.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ file_loc            file location on server
/ file_nm             file name
/ filesize            macro variable storing returned file size
/ fail_reason         macro variable storing reason program failed to retrieve file size
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fdx_get_file_size(file_loc=/my/directory/path,
/                             file_nm=my_file_name.ext,
/                             filesize=fsize,
/                             fail_reason=reason);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_get_file_size(file_loc=,file_nm=,filesize=,fail_reason=reason);

data _null_;
rc=filename('fref',"&file_loc.&file_nm.");
fid=fopen('fref');
if fid ne 0 then do;
&filesize=finfo(fid,'File Size (bytes)');
call symputx("&filesize",&filesize,'G');
end;
else do;
&fail_reason=sysmsg();
call symputx("&fail_reason",&fail_reason,'G');
call symputx("&filesize",0,'G');
end;
run;

%mend;
