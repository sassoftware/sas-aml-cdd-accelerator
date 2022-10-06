/*--------------------------------------------------------------------------------------------------------------------
/ Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
/ SPDX-License-Identifier: Apache-2.0
/
/ PURPOSE      : 
/ DESCRIPTION  : Add metric from a sas process
/--------------------------------------------------------------------------------------------------------------------
/ PARAMETERS USAGE
/--------------------------------------------------------------------------------------------------------------------
/ EXAMPLE:   %fscprocessmetric(processId= foreign key to fsc_process
/                              metricName=
/                              metricDesc=
/                              metricValue=
/                              targetLib= (db_core));
/--------------------------------------------------------------------------------------------------------------------*/

%macro fscProcessMetric(processId=,
                        metricName=,
                        metricDesc=,
                        metricValue=,
                        targetLib=db_core);
                        
   %put NOTE: {START: fscProcessMetric};

   %if %upcase(&dbflavor) = POSTGRES %then %do;   
      proc sql noprint;
        connect to &dbflavor (&coreDBConnOpts);
          select metric_id length=8 into: metric_id
          from connection to &dbflavor
               (select nextval('core.metric_id') as metric_id);
        disconnect from &dbflavor;
      
        insert into  &targetLib..fsc_process_metric(METRIC_ID,
                                                    PROCESS_ID,
                                                    METRIC_NAME,
                                                    METRIC_DESC,
                                                    METRIC_VALUE)    
       values(&metric_id,
              &processId,
              "&metricName",
              "&metricDesc",
              &metricValue);
      quit; 
      %fcf_chkrc;
      %if &bat_abort=Y %then %do;
        %put NOTE: Error inserting process metric;
        %goto  exit;
      %end;                
    %end;

   %let syscc=0;

 %exit:
    %put NOTE: {END: fscProcessMetric};   
    %if &bat_abort=Y %then %abort return 5;
%mend;
