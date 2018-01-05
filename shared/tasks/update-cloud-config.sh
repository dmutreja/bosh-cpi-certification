#!/usr/bin/env bash

set -eu

: ${INFRASTRUCTURE:?}
: ${DIRECTOR_VARS_FILE:?}

source pipelines/shared/utils.sh
source director-state/director.env

bosh -n update-cloud-config pipelines/shared/assets/certification-release/cloud-config.yml \
  -o pipelines/$INFRASTRUCTURE/assets/certification/cloud-config-ops.yml \
  -l environment/metadata \
  -l <( echo "$DIRECTOR_VARS_FILE" ) \
  $( echo ${OPTIONAL_OPS_FILE} )
