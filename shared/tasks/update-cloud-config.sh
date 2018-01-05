#!/usr/bin/env bash

set -eu

: ${INFRASTRUCTURE:?}
: ${DIRECTOR_VARS_FILE:?}

source pipelines/shared/utils.sh
source director-state/director.env

bosh -n update-cloud-config bosh-deployment/vsphere/cloud-config.yml \
  -o bosh-linux-stemcell-builder/ci/assets/reserve-ips.yml \
  -l environment/metadata \
  -l <( echo "$DIRECTOR_VARS_FILE" ) \
  $( echo ${OPTIONAL_OPS_FILE} )
