#!/usr/bin/env bash

set -e

: ${CERTIFICATION_OPS_FILE:?}
: ${DEPLOYMENT_NAME:?}
: ${RELEASE_NAME:?}
: ${STEMCELL_NAME:?}

# inputs
pipelines_dir="$( cd $(dirname $0) && cd ../.. && pwd )"
workspace_dir="$( cd ${pipelines_dir} && cd .. && pwd )"
environment_dir="${workspace_dir}/environment"
deployment_release="${pipelines_dir}/shared/assets/certification-release"
director_state_dir="${workspace_dir}/director-state"

stemcell_path=$(realpath stemcell/*.tgz)
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

metadata="$( cat ${environment_dir}/metadata )"

vsphere_vars=""
if [ -n "${BOSH_VSPHERE_VCENTER_VLAN}" ]; then
  vsphere_vars="-v bosh_vsphere_vcenter_vlan=${BOSH_VSPHERE_VCENTER_VLAN}"
fi

${bosh_cli} interpolate "${pipelines_dir}/shared/assets/certification-release/certification.yml" \
  -o "${CERTIFICATION_OPS_FILE}" \
  -v "deployment_name=${DEPLOYMENT_NAME}" \
  -v "release_name=${RELEASE_NAME}" \
  -v "stemcell_name=${STEMCELL_NAME}" \
  $(echo ${vsphere_vars}) \
  -l "${environment_dir}/metadata" > /tmp/deployment.yml


source "${director_state_dir}/director.env"
export BOSH_CA_CERT="${director_state_dir}/ca_cert.pem"

pushd ${deployment_release}
  time $bosh_cli -n create-release --force --name ${RELEASE_NAME}
  time $bosh_cli -n upload-release
popd

time $bosh_cli -n upload-stemcell ${stemcell_path}
time $bosh_cli -n deploy -d ${DEPLOYMENT_NAME} /tmp/deployment.yml
