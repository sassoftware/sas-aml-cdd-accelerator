#!/bin/bash

#
# shell script to delete existing alerts and related objects
#
PSQL=psql

DBHOST=${SVI_DBHOST:-localhost}
DBPORT=${SVI_DBPORT:-5432}
DATABASE_NM=${SVI_DBNAME:-VisualInvestigator}

DBOWNER=${SVI_PSQL_USER:-dbmsowner}

# psql looks for a password in an environment variable named PGPASSWORD.

if [[ -z ${SVI_PSQL_PWD} ]] ; then
  read -s -p "Password for ${DBOWNER}: " PGPASSWORD
  echo
else
  PGPASSWORD=${SVI_PSQL_PWD}
fi

export PGPASSWORD

d=$(dirname $0)
source $d/bin/functions.sh
initializeDatabaseAccess

# this will set VI_VERSION and the enable/disable strings (in this process)
computeViVersion

echo Truncating scores and alerts from VI ${VI_VERSION} postgresql://${DBHOST}:${DBPORT}/${DATABASE_NM}

read -p "Press [enter] to continue " go
if [[ "$go" == 'n'* ]] ; then 
  exit
fi

${PSQL} -h ${DBHOST} -p ${DBPORT} -U ${DBOWNER} ${DATABASE_NM} <<EOF

delete from svi_alerts.tdc_replicated_object;
delete from svi_alerts.tdc_contributing_object;
$ENABLE_FOR_10_7 delete from svi_alerts.tdc_suppressed_scenario;
$ENABLE_FOR_10_7 delete from svi_alerts.tdc_scenario_fired_event_suppression;
$ENABLE_FOR_10_6 delete from svi_alerts.tdc_scenario_fired_event_disposition;
delete from svi_alerts.tdc_scenario_fired_event;

update svi_alerts.tdc_alerting_event set alert_id = null;
$ENABLE_FOR_10_8 update svi_alerts.tdc_alerting_event set score_id = null;

$ENABLE_FOR_10_8 delete from svi_alerts.tdc_score;
delete from svi_alerts.tdc_alert;
delete from svi_alerts.tdc_alert_action;

delete from svi_alerts.tdc_alerting_event;

$ENABLE_FOR_10_7 delete from svi_vsd_service.vsd_event_history;

$ENABLE_FOR_10_7 vacuum svi_alerts.tdc_suppressed_scenario;
$ENABLE_FOR_10_7 vacuum svi_alerts.tdc_scenario_fired_event_suppression;
$ENABLE_FOR_10_6 vacuum svi_alerts.tdc_scenario_fired_event_disposition;
vacuum svi_alerts.tdc_scenario_fired_event;
vacuum svi_alerts.tdc_alerting_event;
vacuum svi_alerts.tdc_alert;
vacuum svi_alerts.tdc_alert_action;
vacuum svi_alerts.tdc_contributing_object;
vacuum svi_alerts.tdc_replicated_object;
$ENABLE_FOR_10_7 vacuum svi_vsd_service.vsd_event_history;

create table fdhdata.temp_workspaces_tbd as
select document_sheet_id from fdhdata.dh_document_sheet
where document_type_nm = 'alerts';

delete from fdhdata.dh_document_reference_cell where document_sheet_cell_id in 
 (select document_sheet_cell_id from fdhdata.dh_document_sheet_cell where document_sheet_id in
   (select document_sheet_id from fdhdata.temp_workspaces_tbd));

delete from fdhdata.dh_entity_reference_cell where document_sheet_cell_id in 
 (select document_sheet_cell_id from fdhdata.dh_document_sheet_cell where document_sheet_id in
   (select document_sheet_id from fdhdata.temp_workspaces_tbd));

delete from fdhdata.dh_document_sheet_cell where document_sheet_id in (select document_sheet_id from fdhdata.temp_workspaces_tbd);

delete from fdhdata.dh_document_sheet where document_sheet_id in (select document_sheet_id from fdhdata.temp_workspaces_tbd);

drop table fdhdata.temp_workspaces_tbd;

delete from fdhdata.dh_comment where parent_type_nm = 'alerts';

EOF

echo Don\'t forget to reindex the alert entity. 
