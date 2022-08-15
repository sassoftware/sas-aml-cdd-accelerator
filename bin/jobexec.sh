#!/bin/bash

# Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Nick Newbill (nick.newbill@sas.com) / 2022
# This script is executed directly.
# Assumes conf/env_usermods.cfg has been supplied, if not it will help create it.

#set -x

function main__HELP()
{
  echo "
------------------------------------------------------------------------------------------------
SAS INSITIUTE INC. - SAS JOB EXECUTION | v1.0.07192022

  This program was developed and is maintained by SAS Professional Services.

Usage:
  [program] [options]
Options:
  -p, --program        SAS Program your running (default location is [root]/program)
  -t, --tenant         The tenant your executing the job against

  -c, --clean          Clean up ephemeral directories
  -d, --debug          Whether to pass debug options: DEBUG_ALL | DEBUG_MACRO
  -h, --help           This small usage guide
Description:
  This script is used for SAS job execution in a Viya 3.x deployment any SAS programs in the 
  codebase.  The script expects programs to exist under \${BASEDIR}\/programs
------------------------------------------------------------------------------------------------
"
  exit 0
}

function main__SPEC()
{
  printf '\t%s\n' "For more information, type: "${0##*/}" -h"
  exit 0
}

export _START=$(date +%s.%N)
export _WLT=~/.wlt/wlt_kv.sas7bdat

export RED=$(tput setaf 1)
export NRM=$(tput sgr0)
export GRN=$(tput setaf 2)
export ERR=${RED}ERROR:${NRM}
export INFO=${GRN}INFO:${NRM}

if [[ -z "${_BASEDIR+x}" ]];
then
  export WORKING_DIR=$(dirname $(realpath $0))
  export _BASEDIR=$(dirname ${WORKING_DIR})
fi


# Pulls SITEURL and PGHOST from environments file.

if [[ -f "${_BASEDIR}/conf/env_usermods.cfg" ]]; 
then
        source ${_BASEDIR}/conf/env_usermods.cfg 
else
        printf '\t%s\n' "${ERR} You must prepare the env_usermods.cfg file."

        printf '\t%s' "What is your site URL? (e.g. hostname.sample.com): "; read -r TMPSITE
        printf '\t%s' "What is the hostname where PostgreSQL was deployed?: "; read -r TMPPG
cat > ${_BASEDIR}/conf/env_usermods.cfg << EOF
# Environment specific settings.
  
export SITEURL=${TMPSITE}
export PGHOST=${TMPPG}
EOF

        printf '\t%s\n' "${GRN}Environments recorded, run setup again.${NRM}"
        exit 0
fi

[[ -n "${SITEURL}" ]] || { printf '\t%s\n' "${ERR} The Site URL is missing, update the environments file."; exit 1; }
[[ -n "${PGHOST}" ]] || { printf '\t%s\n' "${ERR} The PostgreSQL hostname is missing, update the environment file."; exit 1; }

#################################################################################################
## DECISION TREE
#################################################################################################

function main()
{
  local -xgr program="$(readlink -f "${BASH_SOURCE[0]}")"
  local -r OPTIONS=$(getopt -o p:t:d:hc -l "program:,tenant:,debug:,help,clean" -n "${FUNCNAME[0]}" -- "$@") || return
  eval set -- "$OPTIONS"

  unset SAS_FILE TENANT DEBUG _OPT
  while true ; do
    case "$1" in
      -p|--program)           SAS_FILE="$2"; shift 2;;
      -t|--tenant)            TENANT="$2"; shift 2;;
      -d|--debug)             DEBUG="$2"; shift 2;;
      -c|--clean)             _OPT=1; _dir_clean; shift;;
      -h|--help)              _OPT=1; main__HELP; shift;;
      --)                     shift; break;;
      *)                      main__HELP; shift; break;;
    esac
  done

if [[ "${_OPT}x" == "x" ]];
then
  [[ -n "${SAS_FILE}" ]] || { printf '\t%s\n' "${ERR} SAS Program must be specified. "; main__SPEC; return 1; }
  [[ -n "${TENANT}" ]] || { printf '\t%s\n' "${ERR} Tenant must be specified. "; main__SPEC; return 1; }

  [[ ! -f "${_WLT}" ]] && printf '\t%s\n' "${ERR} A SAS Wallet does not exist, this is requied for Oauth generation. Reference the sas_wallet macro. " && exit 1
  [[ ! -f ${_BASEDIR}/programs/${SAS_FILE} ]] && printf '\t%s\n' "${ERR} SAS Program ${GRN}${SAS_FILE}${NRM} does not exist, programs must reside in ${_BASEDIR}/programs." && exit 1
  [[ -z ${SASROOTDIR+x} ]] && export SASROOTDIR="/opt/sas/${TENANT}"
  [[ ! -d "${SASROOTDIR}" ]] && printf '\t%s\n' "${ERR} The tenant ${GRN}${TENANT}${NRM} is not valid." && exit 1
  [[ -z ${SASDEPLOYID+x} ]] && export SASDEPLOYID="$(basename ${SASROOTDIR})"
  [[ -z ${SASHOME+x} ]] && export SASHOME=${SASROOTDIR}/home
  [[ -z ${SASCONFIG+x} ]] && export SASCONFIG=/opt/sas/${SASDEPLOYID}/config
  [[ ! -d "${_BASEDIR}/log" ]] && mkdir -p ${_BASEDIR}/log

  _f_runjob
fi
}

#################################################################################################
## MAIN EXECUTE OF RUNJOB PROGRAM
#################################################################################################

_f_runjob() 
{
export PATH=$PATH:/opt/sas/spre/home/bin:/opt/sas/spre/home/SASFoundation:${SASHOME}/bin
export _USER=${USER}
export JOBID=$$
export SAS_CMD=/opt/sas/spre/home/SASFoundation/sas
export FILE=$(echo "${SAS_FILE}" | cut -f 1 -d '.')
export STAMP=$(date +%F_%H-%M-%S)
export SASLOGFILE=${FILE}_${JOBID}_${USER}_${STAMP}
export JOBLOGFILE=JobStats-${FILE}_${USER}_${STAMP}

# Create ephereral directories if they don't exist
_dir_create

${SAS_CMD} \
  -autoexec ${_BASEDIR}/programs/user_autoexec.sas \
  -sysin ${_BASEDIR}/programs/${SAS_FILE} \
  -log ${_BASEDIR}/log/${SASLOGFILE}.log \
  -print ${_BASEDIR}/log/${SASLOGFILE}.lst \
  -servicesbaseurl "https://${SASDEPLOYID}.${SITEURL}" \
  -sysparm "${SASDEPLOYID} ${DEBUG}" \
  > /dev/null 2>&1

RC=$?
local _DUR=$(echo "$(date +%s.%N) - ${_START}" | bc)
local _EXE_TIME=`printf "%.2f seconds" ${_DUR}`

# Stats Output
local _FORMAT="%-5s %-20s %-50s\n"
if [ "${RC}" -ne 0 ]; 
then
	if [ "${RC}" -eq 1 ]; 
	then
		export _STAT="WARNING detected during job ${JOBID} execution."
	elif [ "${RC}" -ge 2 ]; 
	then
		export _STAT="ERROR detected during job ${JOBID} execution."
	fi
else export _STAT="Job ${JOBID} finished successfully."
fi

printf "\n" > ${_BASEDIR}/log/${JOBLOGFILE}.log
printf "+  $(date) \n" >> ${_BASEDIR}/log/${JOBLOGFILE}.log
printf "+  ${_STAT} \n" >> ${_BASEDIR}/log/${JOBLOGFILE}.log
printf "+  -------------------------------------------------------------- \n" >> ${_BASEDIR}/log/${JOBLOGFILE}.log
printf "${_FORMAT}" \
	"+" "Job:" "${_BASEDIR}/programs/${SAS_FILE}" \
	"+" "Tenant:" "${TENANT}" \
	"+" "Return Code:" "${RC}" \
	"+" "Execution Time:" "${_EXE_TIME}" \
        "+" "Log Location:" "${_BASEDIR}/log/${SASLOGFILE}.log" >> ${_BASEDIR}/log/${JOBLOGFILE}.log
exit ${RC}
}

#################################################################################################
## CREATE EPHEMERAL DIRECTORIES IN BASELINE
#################################################################################################

function _dir_create()
{
local _LIST="custom_controls data etlops formats log source"
for _DIR in \
  ${_LIST}
do
  mkdir -p ${_BASEDIR}/${_DIR}
done

# Master

mkdir -p ${_BASEDIR}/data/master
mkdir -p ${_BASEDIR}/data/master/{alert,prep,report,rc,nn,ca}

# Stage

mkdir -p ${_BASEDIR}/data/stage
mkdir -p ${_BASEDIR}/data/stage/{alert,bridge,control,dim,fact,watchlist,error,rc,ca,xref,hist_core_stg}
mkdir -p ${_BASEDIR}/data/stage/rc/{acc,ppf,pty}
}

#################################################################################################
## CLEAN EPHEMERAL DIRECTORIES FROM BASELINE
#################################################################################################

function _dir_clean()
{
local _LIST="custom_controls data etlops formats log source"
for _DIR in \
  ${_LIST}
do
  rm -rf ${_BASEDIR}/${_DIR}
done

printf '\t%s\n' "Ephemeral directories cleared. "
exit 0
}

main "$@"
