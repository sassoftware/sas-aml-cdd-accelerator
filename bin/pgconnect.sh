#!/bin/bash

# Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Nick Newbill (nick.newbill@sas.com) / 2022
# This script is executed directly.
# Assumes you have adequate permissions. 

#set -x

function connect()
{
if [ "x$1" == "x" ];
then
  printf '\t%s\n' "You must specify a database your connecting to (e.g. "${0##*/}" [mydatabase]).";
  exit 1;
else
  local OURDB=$1
  printf '\t%s\n' "NOTE: This script assumes you are running this as "sas" or have sudo access.";
  printf '\t%s\n' "Attempting to connect to ${OURDB}...";
fi

if [[ ! -d "/opt/sas/viya/home/postgresql11" ]];
then
  printf '\t%s\n' "SAS Viya does not appear to be installed or your not running this on the postgres node.";
  exit 1;
else
  local _SASROOT=/opt/sas/viya/home
  local _PGSQLROOT=/opt/sas/viya/home/postgresql11
  local _PGSQLEXEC=${_PGSQLROOT}/bin/psql
fi

# Source connection properties
source /opt/sas/viya/config/consul.conf
export _USER=$(whoami)
if [[ " `id -Gn ${2-}` " == *" $1 "* ]];
then
  export CONSUL_HTTP_TOKEN=$(sudo cat /opt/sas/viya/config/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token)
  export PGUSER=$(sudo ${_SASROOT}/bin/sas-bootstrap-config kv read config/application/postgres/username)
  export PGHOST=$(sudo ${_SASROOT}/bin/sas-bootstrap-config kv read config/postgres/sas.dataserver.pool/common/backend_hostname0)
  export PGPORT=$(sudo ${_SASROOT}/bin/sas-bootstrap-config kv read config/postgres/sas.dataserver.pool/common/backend_port0)
  export PGPASSWORD=$(sudo ${_SASROOT}/bin/sas-bootstrap-config kv read config/application/sas/database/postgres/password)
else
  export CONSUL_HTTP_TOKEN=$(cat /opt/sas/viya/config/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token)
  export PGUSER=$(${_SASROOT}/bin/sas-bootstrap-config kv read config/application/postgres/username)
  export PGHOST=$(${_SASROOT}/bin/sas-bootstrap-config kv read config/postgres/sas.dataserver.pool/common/backend_hostname0)
  export PGPORT=$(${_SASROOT}/bin/sas-bootstrap-config kv read config/postgres/sas.dataserver.pool/common/backend_port0)
  export PGPASSWORD=$(${_SASROOT}/bin/sas-bootstrap-config kv read config/application/sas/database/postgres/password)
fi

# Connect to DB
if [ "x$PGHOST" != "x" ];
then
${_PGSQLEXEC} -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} ${OURDB} # > /dev/null 2>&1
fi

# Check for errors
RC=$?
if [ "${RC}" -ne 0 ];
then
  printf '\t%s\n' "There was a problem connecting to database ${OURDB}.";
  exit ${RC};
fi
}

connect "$@"
