/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PROGRAMMER   : Nick Newbill (nick.newbill@sas.com)
/ PURPOSE      : Toggle debug threashold
/ DESCRIPTION  : Sets various options based on input for debugging purposes
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ NAME                DESCRIPTION
/--------------------------------------------------------------------------------------------------------------------
/ DEBUG_MACRO         Options: mprint mprintnest symbolgen source source2 notes
/ DEBUG_ALL           Options: mprint mprintnest symbolgen source source2 notes fullstimer stimer sastrace=',,,sa' msglevel=i
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fdx_set_debug_params;
/--------------------------------------------------------------------------------------------------------------------*/

%macro fdx_set_debug_params();

%if &debug_parm. eq DEBUG_MACRO %then %do;
	options mprint mprintnest symbolgen source source2 notes;
%end;
%else %if &debug_parm. eq DEBUG_ALL %then %do;
	options mprint mprintnest symbolgen source source2 notes fullstimer stimer sastrace=',,,sa' msglevel=i;
%end;
%else %do; /* default to DEBUG_PERF */
	options source notes fullstimer stimer sastrace=',,,sa' msglevel=i;
%end;

%mend;
