#!/usr/bin/env bash

set -e

: ${DIRECTOR_VARS_FILE:?}
: ${INFRASTRUCTURE:?}
: ${USE_REDIS:?}

source pipelines/shared/utils.sh

metadata="$( cat environment/metadata )"
redis_ops=""
if [ "${USE_REDIS}" == true ]; then
  redis_ops="-o pipelines/shared/assets/ops/redis.yml"
fi

bosh2 int \
  -o bosh-deployment/${INFRASTRUCTURE}/cpi.yml \
  -o bosh-deployment/powerdns.yml \
  -o bosh-deployment/jumpbox-user.yml \
  -o pipelines/shared/assets/ops/custom-releases.yml \
  -o pipelines/${INFRASTRUCTURE}/assets/ops/custom-cpi-release.yml \
  $( echo ${redis_ops} ) \
  $( echo ${OPTIONAL_OPS_FILE} ) \
  -v bosh_release_uri="file://$(echo bosh-release/*.tgz)" \
  -v cpi_release_uri="file://$(echo cpi-release/*.tgz)" \
  -v stemcell_uri="file://$(echo stemcell/*.tgz)" \
  -v director_name=bosh \
  -l <( echo "${DIRECTOR_VARS_FILE}" ) \
  bosh-deployment/bosh.yml > /tmp/director.yml

bosh2 int \
  -l environment/metadata \
  /tmp/director.yml > director-config/director.yml
