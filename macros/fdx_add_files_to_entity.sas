/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Kristen Moody (kristen.moody@sas.com)
/ PURPOSE      : Add files to SAS Visual Investigator object
/ DESCRIPTION  : This macro creates a target folder on the SAS Content Server and places a file from the
/                source folder on the server within that target folder. Special characters are removed
/                from the name to prevent errors during processing.
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ entity_type         id of the object to add comment
/ entity_id           type of the object for &object_id
/ sdir_ref            message to post in the comment
/ sfname              name of source file
/ tdir_ref            target directory location (on SAS Content Server)
/ desc                description of file that gets printed to Content Server
/ error_ind           determines whether to print a NOTE or ERROR to the log if the API call fails
/ fail_reason         prints a fail reason to a macro variable
/ check_exists        checks if file has already been added to object
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE: %fdx_add_files_to_entity(entity_type=tm_cases,
/                                   entity_id=2020900045,
/                                   sdir_ref=/your/directory/path/on/the/server/,
/                                   sfname=your_file_name.ext,
/                                   tdir_ref=/path/on/content/server/,
/                                   desc=%str(Attached evidence for Case 2020900045),
/                                   error_ind=N,
/                                   fail_reason=reason,
/                                   check_exists=Y
/                                   );
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_add_files_to_entity(entity_type=, entity_id=, sdir_ref=, sfname=, 
		tdir_ref=, desc=, error_ind=,fail_reason=reason,check_exists=Y);
%put NOTE: {BEGIN: fdx_add_files_to_entity};


%global &fail_reason add_files_abort;	
	/*set error_ind to Y if no value provided*/
	%if %length(&error_ind) = 0 %then %do;
		%let error_ind=Y;
	%end;

/*check that file exists*/
%let sfile = &sdir_ref.%superq(sfname);
%put NOTE: sfile = %superq(sfile);
	%if %sysfunc(fileexist(%superq(sfile))) %then %do;
		%put NOTE: The external file %superq(sfile) exists; 
	%end;
	%else %do;
			%put {WARNING: The external file %superq(sfile) does not exist.};
			%let syscc=4;
			%let &fail_reason=The external file %superq(sfile) does not exist.;
			%let bat_abort=Y;
			%goto MACRO_END;
	%end;

	/* find content type of the file */
	%let ext = %scan(%superq(sfname), -1, '.');
	%put NOTE: file extension is &ext;

	%if "&ext"="exe" %then
		%do;
			%put {WARNING: Cannot upload .EXE files};
			%let syscc=4;
			%let &fail_reason=Cannot upload .EXE files;
			%goto MACRO_END;
		%end;
	
	/*get file size to ensure valid*/
	%if %length(&sdir_ref) gt 0 %then %do;
		%fdx_get_file_size(file_loc=&sdir_ref,
			file_nm=%superq(sfname),
			filesize=att_size,
			fail_reason=&fail_reason);
		%put NOTE: attachment file size = &att_size;
		%if &att_size = 0 OR &att_size > 524288000 %then %do;
			%put WARNING: Attachment %superq(sfname) has invalid size (size=&att_size);
			%let bat_abort=Y;
			%let &fail_reason=Attachment %superq(sfname) has invalid size (size=&att_size);
			%goto MACRO_END;
		%end;
	%end;

	%put NOTE: tdir = &tdir_ref.;
	* %fdx_create_cont_srv_sbfldr(fldr_pth=%str(&tdir_ref),error_ind=N);
	
	%let tdir_ref=&tdir_ref._&SYSDATE._&SYSPROCESSID._&entity_id.;
	%put NOTE: tdir_ref = &tdir_ref. ;
	%fdx_create_cont_srv_sbfldr(fldr_pth=%str(&tdir_ref),error_ind=N);

		
	

	/* Construct URL */
	%let _end_point = folders/folders/@item?path=;
	%let _url = &_end_point&tdir_ref;

	/* Assign Temporary header files */
	filename fldhdr "%sysfunc(pathname(work))/fldr_hdrs";
	filename fldrspo "%sysfunc(pathname(work))/fldr_resp_o";
	filename fldhdro "%sysfunc(pathname(work))/fldr_hdrs_o";
	%let SYS_PROCHTTP_STATUS_CODE=0;
	%put ****PROC HTTP CODE BEFORE CALL**** &SYS_PROCHTTP_STATUS_CODE;

	/* Grab the Target folder ID for attachments - All attachments will be uploaded to this folder.*/
	/*%fdx_ws_http_get_json(url=%superq(_url),_ws_out_json=response, error_ind=Y);*/
	


	%if &bat_abort=Y %then
		%do;
			%put NOTE: Failed to Get parent folder ID - check fdx_ws_http_get_json macro;
			%let &fail_reason=Failed to Get parent folder ID - check fdx_ws_http_get_json macro;
			%goto MACRO_END;
		%end;
	%else
		%do;

			/* read the json and get the Folder ID */
			libname fldresp json fileref=ws_out;

			proc sql noprint;
				select href into : folderId trimmed from fldresp.links where rel='self';
			quit;

		%end;

	/******** Prepare to upload file to target folder **************/
	/* Construct URL with Target folder ID */
	%let _end_point = files/files;
	%let _filter = ?parentFolderUri=&folderId;
	%let _url=&_end_point&_filter;
	%put %superq(_url);

	/* Assign Temporary header files */
	filename fnhdr "%sysfunc(pathname(work))/fn_hdrs";
	filename fnrspo "%sysfunc(pathname(work))/fn_resp_o";
	filename fnhdro "%sysfunc(pathname(work))/fn_hdrs_o";

	/* Remove troublesome chars from file names */
	data _null_;
	length attachment_nm sfname tfname $2000;
		attachment_nm="%bquote(&sfname)";
		/*C2A7   section*/
		sfname=tranwrd(strip(attachment_nm),'c2a7'x,'?');
		tfname=tranwrd(strip(attachment_nm),'c2a7'x,'S');
		/*E28093 dash*/
		sfname=tranwrd(strip(sfname),'e28093'x,'?');
		tfname=tranwrd(strip(tfname),'e28093'x,'-');
		/*E28094 dash*/
		sfname=tranwrd(strip(sfname),'e28094'x,'?');
		tfname=tranwrd(strip(tfname),'e28094'x,'-');
		/*ascii single quote */
		sfname=tranwrd(strip(sfname),'27'x,"\'");
		tfname=tranwrd(strip(tfname),"'",'^');
		/*E28099 unicode right single quote*/
		sfname=tranwrd(strip(sfname),'e28099'x,'\'||'e28099'x);
		tfname=tranwrd(strip(tfname),'e28099'x,'^');
		/*E2809C latin a*/
		sfname=tranwrd(strip(sfname),'e2809c'x,'?');
		tfname=tranwrd(strip(tfname),'e2809c'x,'_');
		/*E284A2 trademark sign */
		sfname=tranwrd(strip(sfname),'e280A2'x,'?');
		tfname=tranwrd(strip(tfname),'e280A2'x,'_TM');
		/*accented e*/
		sfname=tranwrd(strip(sfname),'c3a9'x,'?');
		tfname=tranwrd(strip(tfname),'c3a9'x,'e');		
		/*left and right parenthesis*/
		sfname=tranwrd(tranwrd(sfname,'(','\('),')','\)');
		tfname=tranwrd(tranwrd(tfname,'(','\('),')','\)');
		/*dollar sign*/
		sfname=tranwrd(strip(sfname),'$','\$');
		tfname=tranwrd(strip(tfname),'$','\$');
		/*ampersands*/
		sfname=tranwrd(strip(%str(sfname)),'&','\&');
		tfname=tranwrd(strip(%str(tfname)),'&','\&');
		/*semicolon*/
		sfname=tranwrd(strip(%str(sfname)),';','\;');
		tfname=tranwrd(strip(%str(tfname)),';','\;');
		call symput("sfname",strip(sfname));
		call symput("tfname",strip(tfname));
	run;
	%put NOTE: sfname=%superq(sfname) , tfname=%superq(tfname) ;
	
	/*check if file exists*/proc sql noprint;
	select count(*) into :exist_flg trimmed from fdhdata.dh_file 
		where document_type_nm="&entity_type"
		and document_id="&entity_id"
		and name_nm = "%superq(tfname)";
	quit;
	%if &exist_flg gt 0 and &check_exists eq Y %then %do;
			%put NOTE: file %superq(tfname) is already attached to &entity_type with id &entity_id;
			%goto MACRO_END;
	%end;
	
	/*move converted name to temporary work location*/
	%fdx_cp_files(sdir=&sdir_ref.,
					tdir=%sysfunc(pathname(work)),
					  sfile_nm=%superq(sfname),
					  tfile_nm=%superq(tfname),
					  util_loc=%str(/home/viadmin)								   
					);
	%let sdir_ref=%sysfunc(pathname(work));
	%let sfname=%superq(tfname);
	%put NOTE: sdir_ref=&sdir_ref , sfname=%superq(sfname) ;
	
	data _null_;
	length filepth $32767;
	filepth = strip("&sdir_ref.") || '/' || strip("%superq(sfname)");
	sdir_ref = strip("&sdir_ref.");
	sfname = strip("%superq(sfname)");
	call symputx("filepth",strip(filepth),'G');
	call symputx("sfname",strip(sfname),'G');
	run;
	%put NOTE: sfname = %superq(sfname) , filepth = %superq(filepth) ;
	
	filename fname "%superq(filepth)";

	proc sql noprint;
		select mime_type into :cntnt_typ trimmed from DB_CORE.PUB_MIME_TYPES where 
			extension="&ext";
	quit;

	%fcf_chkrc;

	%if &bat_abort=Y %then
		%do;
			%put ERROR: Error retreving mime type;
			%let &fail_reason=Error retrieving mime type;
			%goto MACRO_END;
		%end;
	%if %symexist(cntnt_typ) ne 0 %then
		%do;
			%put NOTE: Content-Type is &cntnt_typ;
		%end;
	%else
		%do;
			%put NOTE: Mime type not found for extension - &ext. Using default mime type - application/octet-stream;
			%let cntnt_typ = application/octet-stream;
		%end;

	%let syscc=0;
	%let SYS_PROCHTTP_STATUS_CODE=0;
	%put ****Upload - PROC HTTP CODE BEFORE CALL**** &SYS_PROCHTTP_STATUS_CODE;

	%let contentDisp=%str(attachment;)filename=%bquote(')&sfname%bquote(');
	%put NOTE: contentDisp = &contentDisp;
	%fdx_ws_http_post_json(url=%superq(_url), ws_in_json_fref=fname, _ws_out_json_fref=fnrspo, error_ind=N, content_disp=%superq(contentDisp), debug_print=N);
	
	%if &SYS_PROCHTTP_STATUS_CODE gt 409 %then %do;
		%let bat_abort=Y;
	%end;	

	

	%if &bat_abort=Y %then
		%do;
			%put ERROR: Failed to upload file - check fdx_ws_http_post_json macro;
			%let &fail_reason=Failed to upload file - check fdx_ws_http_post_json macro;
			%goto MACRO_END;
		%end;
	%else

	/* read the response json and get the file attributes*/
	/* if there is a very odd failure that isn't really a failure that causes a retry to get a 409 because the first "failed" request actually succeeded then get the file info*/
	%if &SYS_PROCHTTP_STATUS_CODE eq 409 %then %do;
	                                        ;
    data _null_;
	   call symput("_url",strip(substr("&folderId.",2))||"/members");
	run;

		%fdx_ws_http_get_json(url=&_url., error_ind=N);

		libname fldrinf json fileref=ws_out;

		proc sql;
		select count into:member_cnt trimmed from fldrinf.root;
		quit;

		%if &member_cnt eq 0 %then %do;
			%let bat_abort=Y;
			%put ERROR: Failed to upload file - check fdx_ws_http_post_json macro;
			%let &fail_reason=Failed to upload file - check fdx_ws_http_post_json macro;
			%goto MACRO_END;
		%end;

		proc sql;
		select uri into:_url from fldrinf.items where name="&tfname";
		quit;

		%fdx_ws_http_get_json(url=&_url., error_ind=N);

		libname fnresp json fileref=ws_out;
	%end;
	%else %do;
		libname fnresp json fileref=fnrspo;
	%end;


	proc sql noprint;
		select id, contentDisposition, name, size format 20. into :fileId, 
			:cont_Disp, :fName, :fSize trimmed from fnresp.root where name="&sfname";
		select href into : fLocation from fnresp.links where rel='self';
	quit;

	%put NOTE: Source File Name = %superq(sfname), File ID is = &fileId, File Name = %superq(fname);
	
	/*ensure that file name does not exceed 100 characters before adding to entity*/
	%let fname_desc=;
	%let orig_fname=;
	%if %length(%superq(fname)) gt 100 %then %do;
		data _null_;
			/*truncate desc for file description limit*/
			length desc $250;
			length long_desc $1000;
			long_desc="%superq(desc)|%superq(fname)";
			desc=substr(long_desc,1,250);
			call symput("desc",desc);
		run;
		%let fname_desc=%superq(fname);
		%let orig_fname=%superq(fname);
		%let fname=%sysfunc(UUIDGEN());
		%let comment_txt=Batch attachment file name is too long. Renaming from %superq(orig_fname) to &fname;
		%fdx_add_comment(object_id=&entity_id, object_type=&entity_type,
                       message=%superq(comment_txt));
	%end; /*end if length tfname gt 100*/


	/******** Prepare to link file to the entity **************/
	filename finfo "%sysfunc(pathname(work))/finfo_json.json";

	/* Construct JSON to link the file to entity */
	proc json out=finfo;
			write open object;
			write values "id" "&fileId";
			write values "name" "%superq(fName)";
			write values "location" "&fLocation";
			write values "type" "&cntnt_typ";
			write values "size" "&fSize";
			write values "description" "&desc";		
			write close;
	run;

	/* Construct URL to link the file to entity */			

	%if &entity_type=case %then
		%do;
			%let link_to_entiy_type  = tm_cases;
		%end;
	%else %if &entity_type=alert %then
		%do;
			%let link_to_entiy_type  = alerts;
		%end;
	%else %if &entity_type=subject %then
		%do;
			%let link_to_entiy_type  = subject;
		%end;
	%else %if &entity_type=report %then
		%do;
			%let link_to_entiy_type  = report;
		%end;
	%else %do;
	/* really don't need any of the above mapping, you should use the VI object type name as entity_type */
		%let link_to_entiy_type=&entity_type;
	%end;
	
	/* Construct URL with Target folder ID */
	data test2;
	length entity_id $50;
	entity_id="%superq(entity_id)";
    entity_id=urlencode(strip(tranwrd(entity_id,'/','_')));
	call symput("entity_id",strip(entity_id));
	run;

	%put NOTE: entity_id is now %superq(entity_id);
	%let _end_point = svi-datahub/documents/&link_to_entiy_type;
	%let _filter1 = %superq(entity_id);
	%let _filter2 = attachments;
	%let _url=&_end_point/%superq(_filter1)/&_filter2;
	%put NOTE: url is %superq(_url)

	/* Temporary header files*/
	filename c_hdrs "%sysfunc(pathname(work))/c_hdrs";
	filename c_resp_o "%sysfunc(pathname(work))/c_resp_o";
	filename c_hdrs_o "%sysfunc(pathname(work))/c_hdrs_o";

	%fdx_ws_http_post_json(url=%superq(_url), ws_in_json_fref=finfo, _ws_out_json_fref=c_resp_o, error_ind=&error_ind., debug_print=N);

	%if &bat_abort=Y or &SYS_PROCHTTP_STATUS_CODE gt 201 %then
		%do;
			%put NOTE: Failed to link to entity - check fdx_ws_http_post_json macro;
			%let &fail_reason=Failed to link to entity - check fdx_ws_http_post_json macro;
			%goto MACRO_END;
		%end;

	options notes;
	quit;
%MACRO_END:
	%let add_files_abort=&bat_abort;
	/*The calling program should decide if aborting.*/
	%put NOTE: {END: fdx_add_files_to_entity;
%mend fdx_add_files_to_entity;
