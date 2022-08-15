#!/bin/sh

# Copyright © 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Nick Newbill (nick.newbill@sas.com) / 2022
# This script is executed directly.
# Assumes git has been installed.

#set -x

export WORKING_DIR=$(dirname $(realpath $0))
export _BASEDIR=$(dirname ${WORKING_DIR})
export _ROOTDIR=$(dirname ${_BASEDIR})
export _USER=$USER

export VC=$(tput setaf 45)
export GRN=$(tput setaf 2)
export RED=$(tput setaf 1)
export NRM=$(tput sgr0)
export TAG="[ ${GRN}GIT${NRM} ]"

if [[ ! -d "${_BASEDIR}/.git" ]];
then
  printf '\n%s\n' "${TAG} Your not working in a cloned repository."
else
  export GITURL=$(git config --get remote.origin.url)
  export CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)

fi

function main__HELP()
{
  echo "
------------------------------------------------------------------------------------------------
SAS INSITIUTE INC. - GIT TOOLKIT | v1.0.08062022

  This program was developed and is maintained by SAS Professional Services.

Usage:
  [program] [options]
Options:
  -s, --stage         Initializes a cloned git repository with a develop and stage branch
  -d, --developer     Sets up a unique developer local cloned repository
  -r, --delstg        Removes the develop and stage branches
Description:
  This script suppliments a highly specific migration and release strategy for code development
  during project implementations.
------------------------------------------------------------------------------------------------
"
  exit 0
}

function main()
{
  local -xgr program="$(readlink -f "${BASH_SOURCE[0]}")"
  local -r OPTIONS=$(getopt -o srd -l "stage,developer,delstg" -n "${FUNCNAME[0]}" -- "$@") || return
  eval set -- "$OPTIONS"

  while true ; do
          case "$1" in
                  -s|--stage)     _f_git_stage; shift;;
                  -d|--developer) _f_git_developer; shift;;
                  -r|--delstg)    _f_git_delstg; shift;;
                  --)             shift; break;;
                  *)              shift; break;;
          esac
  done
}

function _f_git_stage()
{
        cd ${_BASEDIR}
        printf '\n%s\n' "${TAG} Creating a development branch..."
        git branch develop > /dev/null 2>&1
        git push --set-upstream origin develop > /dev/null 2>&1
        printf '\n%s\n' "${TAG} Creating a ${GRN}stage${NRM} branch..."
        git branch stage > /dev/null 2>&1
        git push --set-upstream origin stage > /dev/null 2>&1
        printf '\n%s\n' "${TAG} Checking out the ${GRN}develop${NRM} branch..."
        git checkout develop > /dev/null 2>&1
        _f_which_branch
}

function _f_git_delstg()
{
  cd ${_BASEDIR}
  if [ "${CUR_BRANCH}" == "develop" ] || [ "${CUR_BRANCH}" == "stage" ];
  then
    git checkout main > /dev/null 2>&1
  fi
  printf '\n%s\n' "${TAG} Deleting the ${GRN}develop${NRM} and ${GRN}stage${NRM} branches."
  git branch -d develop > /dev/null 2>&1
  git branch -d stage > /dev/null 2>&1
  git push origin --delete develop > /dev/null 2>&1
  git push origin --delete stage > /dev/null 2>&1
  printf '\n%s\n' "${TAG} The ${GRN}develop${NRM} and ${GRN}stage${NRM} branches have been removed both locally and remote."
  _f_which_branch
}

function _f_git_developer()
{
  cd ${_ROOTDIR}
  export DEVBRNCH=${_USER}
  printf '\n%s\n' "${TAG} Cloning the remote repository to ${GRN}${DEVBRNCH}${NRM} under ${GRN}${_ROOTDIR}${NRM}."
  git clone ${GITURL} ${DEVBRNCH} > /dev/null 2>&1
  cd ${_ROOTDIR}/${DEVBRNCH} > /dev/null 2>&1
  git pull origin develop > /dev/null 2>&1
  git checkout develop > /dev/null 2>&1
  printf '\n%s\n' "${TAG} Creating a developer branch ${GRN}${DEVBRNCH}${NRM}."
  git checkout -b ${DEVBRNCH} develop > /dev/null 2>&1
  git push --set-upstream origin ${DEVBRNCH} > /dev/null 2>&1
  printf '\n%s\n' "${TAG} New local developer repository deployed to: ${GRN}${_ROOTDIR}/${DEVBRNCH}${NRM}"
}


function _f_which_branch()
{
        export CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        printf '\n%s\n' "${TAG} Currently working in the ${GRN}${CUR_BRANCH}${NRM} branch."
}

main "$@"
