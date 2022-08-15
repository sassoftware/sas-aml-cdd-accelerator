/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Pete Ferrera (pete.ferrera@sas.com)
/ PURPOSE      : Create password protected dataset
/ DESCRIPTION  : This macro executes a PROC JSON to create a request payload for an HTTP call to create
/                a relationship between two entities.
/
/ SAS WALLET SETUP INSTRUCTIONS:
/                1. Create hidden folder for the wallet -> mkdir ~/.wlt
/                2. Run wallet generation method -> %sas_wallet(create)
/                3. Protect the wallet -> chmod 600 ~/.wlt/wlt_kv.sas7bdat
/                4. Put values into wallet -> %sas_wallet(put,user,u123123)
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ toObjectTypeName    vi typename of object on "to" side of relationship,
/ toObjectId          vi object id of object on "to" side of relationship,
/ fromObjectTypeName  vi typename of object on "from" side of relationship,
/ fromObjectID        vi object id of object on "from" side of relationship,
/ use_api             ONLY for call to fdx_get_related_objects
/                     Y = safe but bad performance
/                     N = use tables for better performance, but may not handle all relationships
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:    %fdx_ws_relate_vi_objects(toObjectTypeName=PTY,
/                                       toObjectId=FIS-?????,
/                                       fromObjectTypeName=tm_cases,
/                                       fromObjectID=202007178);
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_ws_relate_vi_objects(toObjectTypeName=,
			toObjectId=,
			fromObjectTypeName=,
			fromObjectID=,
			error_ind=N,
			use_api=Y,
			check_exists=Y);
%if &check_exists eq Y %then %do;			
/*first check the rel already exists*/
	%fdx_get_related_objects(
				object_type=&fromObjectTypeName,
				object_id=&fromObjectID,
				related_object_type=&toObjectTypeName,
				out_ds=&toObjectTypeName._ids,
				use_api=&use_api);
	proc sql noprint;
	select count(*) into: &toObjectTypeName._exists from &toObjectTypeName._ids 
	where strip(object_id)=strip("&toObjectId");
	quit;
	%put NOTE: &toObjectTypeName._exists is &&&toObjectTypeName._exists;
	%if &&&toObjectTypeName._exists gt 0 %then %do;
	%put NOTE: Relationships already exists;
	%goto RELATE_END;
	%end;
%end;
/*API info:*/
/*https://playpen.pub01au.vsp.sas.com/svi-datahub/links*/
/*Request Method: POST*/
/*{"@type":"DocumentLink",*/
/*	"relationshipTypeName":"PTY",*/
/*	"fieldValues":{},*/
/*	"fromObjectTypeName":"tm_cases",*/
/*	"fromObjectId":"202007178",*/
/*	"toObjectTypeName":"PTY",*/
/*	"toObjectId":"FIS-??????"}*/
filename relreq "%sysfunc(pathname(work))/relate_&fromObjectTypeName._to_&toObjectTypeName._req.txt";

proc json out=relreq pretty nosastags;
write values "@type" "DocumentLink";
write values "relationshipTypeName" "&toObjectTypeName";
write values "fieldValues";
write open object;
write close;
write values "fromObjectTypeName" "&fromObjectTypeName";
write values "fromObjectId" "&fromObjectId";
write values "toObjectTypeName" "&toObjectTypeName";
write values "toObjectId" "&toObjectid";
run;

data _null_;
  infile relreq lrecl=32767;
  input;
  put "DEBUG: > " _infile_;
run;

filename relrsp "%sysfunc(pathname(work))/relate_&fromObjectTypeName._to_&toObjectTypeName._rsp.txt";

%fdx_ws_http_post_json(url=/svi-datahub/links, ws_in_json_fref=relreq, _ws_out_json_fref=relrsp,error_ind=&error_ind);

%RELATE_END:

%mend;

