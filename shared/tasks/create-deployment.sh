#!/usr/bin/env bash

set -e

: ${INFRASTRUCTURE:?}
: ${DEPLOYMENT_NAME:?}
: ${RELEASE_NAME:?}
: ${STEMCELL_NAME:?}

source pipelines/shared/utils.sh

vsphere_vars=""
if [ -n "${VCENTER_NETWORK_NAME}" ]; then
  vsphere_vars="-v network_name=${VCENTER_NETWORK_NAME}"
fi

bosh2 int pipelines/shared/assets/certification-release/certification.yml \
  -v "deployment_name=${DEPLOYMENT_NAME}" \
  -v "release_name=${RELEASE_NAME}" \
  -v "stemcell_name=${STEMCELL_NAME}" \
  $(echo ${vsphere_vars}) \
  -l environment/metadata > /tmp/deployment.yml

source director-state/director.env

pushd pipelines/shared/assets/certification-release
  time bosh2 -n create-release --force --name ${RELEASE_NAME}
  time bosh2 -n upload-release
popd

time bosh2 -n update-cloud-config \
  -o pipelines/${INFRASTRUCTURE}/assets/certification/cloud-config-ops.yml \
  -l environment/metadata \
  $(echo ${vsphere_vars}) \
  pipelines/shared/assets/certification-release/cloud-config.yml
time bosh2 -n upload-stemcell $( realpath stemcell/*.tgz )
time bosh2 -n deploy -d ${DEPLOYMENT_NAME} /tmp/deployment.yml
