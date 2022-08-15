/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Execute Web Service GET request to retrieve current document
/ DESCRIPTION  : This macro determines if the provided folder exists on the content server by
/                executing a get request. If the supplied folder exists, a note is printed to
/                the log saying "subfolder already exists". Otherwise, the macro executes a POST
/                call to create the folder.
/                If the parent folder does not exist, an error is printed to log saying "Parent folder
/                structure does not exist. Please create parent folder before trying to create subfolder".
/
/                The error_ind parameter is passed to the fdx_ws_http_get_json and fdx_ws_https_post_json
/                macros. When the parameter is set to N, a NOTE is written to the log as to why the API
/                call failed rather than an ERROR. This prevents the program from failing due to a bad
/                request when looping through the calls, and will finish the loop.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ fldr_pth         path on Content Server user wishes to create
/ error_ind        gets passed to HTTP macros to either print a NOTE or an ERROR if the API call fails
/ fail_reason      macro variable storing reason for failure
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:  %fdx_create_cont_srv_sbfldr(fldr_pth=,
/                         error_ind=,
/                         fail_reason=
/                         );
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_create_cont_srv_sbfldr(fldr_pth=,error_ind=,fail_reason=reason);

%if %length(error_ind)=0 %then %do;
	%let error_ind=Y;
%end;

%let sub_fldr = %scan(&fldr_pth, -1, '/');
%let parent_fldr = %substr(&fldr_pth, 1, %length("&fldr_pth")- %length("&sub_fldr") - 1); 

%put NOTE: fldr_pth = &fldr_pth, sub_fldr = &sub_fldr, parent_fldr = &parent_fldr; 



/****** check if sub_fldr exists*****/
%let _end_point = folders/folders/@item?path=;
%let _url = &_end_point&fldr_pth.;

/*GET request to determine if subfolder exists*/
%fdx_ws_http_get_json(url=&_url.,_ws_out_json=response, _ws_http_code=code, error_ind=N);
%put NOTE: code = &code;

%if &code = 404 %then %do;
	%put NOTE: &fldr_pth does not exist - must create subfolder for &sub_fldr;
	
	/*get parent folder id*/
	%let parent_url= &_end_point&parent_fldr;
	%put NOTE: parent_url = &parent_url;
	%fdx_ws_http_get_json(url=&parent_url, _ws_http_code=parent_code, error_ind=&error_ind.);
	%put NOTE: parent_code = &parent_code.;
		
		/*parent_fldr does not exist - print error*/
		%if &parent_code = 404 %then %do;
			%put ERROR: Parent folder structure does not exist. Please create parent folder before trying to create subfolder;
			%let &fail_reason=Parent folder structure does not exist. Please create parent folder before trying to create subfolder;
			%goto MACRO_END;
		%end;
		
		/*parent_fldr exists - continue to create sub_fldr*/
		%else %if &parent_code = 200 or &parent_code = 201 %then %do;
	
					%fsccheckrc;
					%if &bat_abort=Y %then %do;
						%put NOTE: macro failed - check fdx_ws_http_get_json;
						%let &fail_reason=fdx_create_content_srv_subfolder failed check fdx_ws_http_get_json to create parent folder;
						%goto MACRO_END;
					%end;
					
				libname fldresp json fileref=ws_out;
				proc sql noprint;
				select href into :parentFolderId from fldresp.links where rel='self'
				;quit;
				%put NOTE: parentFolderId = &parentFolderId.;
							
					%fsccheckrc;
					%if &bat_abort=Y %then %do;
						%put NOTE: libname failed - check proc sql to create parentFolderId;
						%goto MACRO_END;
					%end;
				
				/*set POST url*/
				%let create_url = %qcmpres(%str(folders/folders?parentFolderUri=&parentFolderId.));
				filename fld_pth "%sysfunc(pathname(work))/create_subfldr_json";
				
				/*create json for request payload*/
				proc json out=fld_pth pretty;
				write values "name" "&sub_fldr.";
				run;
				
				/*make API call*/
				%fdx_ws_http_post_json(url=%str(&create_url),ws_in_json_fref=fld_pth, _ws_out_json=fldr_response, error_ind=&error_ind);
										
					%fsccheckrc;
					%if &bat_abort=Y %then %do;
						%put NOTE: macro failed - check fdx_ws_http_post_json;
						%goto MACRO_END;
					%end;
		%end;
		
		/*if GET returns 500 error, 401 error, etc */
		%else %do;
			%PUT NOTE: macro failed - check fdx_ws_http_get_json;
		%end;

%end;

/*if get request produces 201 code then print an note to the log thatsubfolder already exists*/
%else %if &code = 201 or &code = 200 %then %do;
	%put NOTE: &fldr_pth exists;
%end;



/*if GET fails print an error to the log*/
%else %do;
	%put ERROR: GET to retrieve folder id failed - check fdx_ws_http_get_json macro;
%end;


%MACRO_END:
%mend;
