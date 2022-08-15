/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PURPOSE      : 
/ DESCRIPTION  : Track a job process
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fscprocess(processAction= ('START','COMPLETE','UPDATE')
/                        processStatus= use when processAction=('END','UPDATE')
/                        jobId= foreign key to fsc_job
/                        processId=
/                        targetLIb= (core));
/--------------------------------------------------------------------------------------------------------------------*/

%macro fscprocess(processAction=,
                  processStatus=,
                  jobId=,
                  processId=,
                  processParentId=,
                  targetLib=core);

   %put NOTE: {START: fscprocess};
   
   %if &processParentId eq %then %do;
      %let processParentId=-1;
   %end;
   /******************************************/ 
   %let step=fscprocess;
   /******************************************/ 
   %let cdate=%sysfunc(datetime(),datetime22.);

   %if %upcase(&processAction) eq START %then %do;   
     %if %upcase(&dbflavor) = POSTGRES %then %do; 
         proc sql noprint;
            connect to &dbflavor (&coreDBConnOpts);
               select pid length=8 into: pid
               from connection to &dbflavor
               (select nextval('core.process_id') as pid);
            disconnect from &dbflavor;
            
            insert into &targetLib..fsc_process(PROCESS_ID,
                                                JOB_ID,
                                                PROCESS_START_DT,
                                                PROCESS_PARENT_ID,
                                                PROCESS_STATUS,
                                                Run_Date)
            values(&pid,
                   &jobId,
                   "&cdate"dt,
                   &processParentId,
                   'STARTED',
                   &runasofdate);
         quit; 
         %fcf_chkrc;
         %if &bat_abort=Y %then %do;
            %put NOTE: Error inserting process;
            %goto  exit;
         %end;                
     %end;
   %end;
   %else %if %upcase(&processAction) eq COMPLETE %then %do; 
        %if &processStatus ne ERROR %then %do;
            proc sql noprint;
               update &targetlib..fsc_process
               set process_end_dt=datetime(),
                   process_status="&processStatus"
               where process_Id=&processId ;  
            quit;
         %end; 
         %else %do;
            proc sql noprint;
               update &targetlib..fsc_process
               set process_end_dt=datetime(),
                   process_status='ERROR',
                   process_notes="&globalErr"
               where process_Id=&processId;
            quit; 

         %if &ppid ne  %then %do;
               proc sql noprint;
                 update &targetlib..fsc_process
                 set process_end_dt=datetime(),
                     process_status='ERROR',
                     process_notes="&globalErr"
                 where process_Id=&ppid;
               quit;                                 
            %end;           

        %end;
   %end;
   %else %if %upcase(&processAction) eq UPDATE %then %do;   
      proc sql noprint;
         update &targetLib..fsc_process
         set process_status="&processStatus"
         where process_Id=&processId;
      quit;   

   %end;
   %else %do;
      %put ERROR: invalid processAction &processAction;

   %end;
 %exit:
   %put NOTE: {END: fscprocess};
   %if &bat_abort=Y %then %abort return 5;
%mend ;
