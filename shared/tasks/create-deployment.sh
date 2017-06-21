#!/usr/bin/env bash

set -e

: ${CERTIFICATION_OPS_FILE:?}
: ${DEPLOYMENT_NAME:?}
: ${RELEASE_NAME:?}
: ${STEMCELL_NAME:?}

source pipelines/shared/utils.sh

vsphere_vars=""
if [ -n "${BOSH_VSPHERE_VCENTER_VLAN}" ]; then
  vsphere_vars="-v bosh_vsphere_vcenter_vlan=${BOSH_VSPHERE_VCENTER_VLAN}"
fi

bosh2 int pipelines/shared/assets/certification-release/certification.yml \
  -o "${CERTIFICATION_OPS_FILE}" \
  -v "deployment_name=${DEPLOYMENT_NAME}" \
  -v "release_name=${RELEASE_NAME}" \
  -v "stemcell_name=${STEMCELL_NAME}" \
  $(echo ${vsphere_vars}) \
  -l environment/metadata > /tmp/deployment.yml

source director-state/director.env
export BOSH_CA_CERT=director-state/ca_cert.pem

pushd pipelines/shared/assets/certification-release
  time bosh2 -n create-release --force --name ${RELEASE_NAME}
  time bosh2 -n upload-release
popd

time bosh2 -n upload-stemcell $( realpath stemcell/*.tgz )
time bosh2 -n deploy -d ${DEPLOYMENT_NAME} /tmp/deployment.yml
