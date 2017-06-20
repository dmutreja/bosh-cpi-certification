#!/usr/bin/env bash

set -e

: ${CERTIFICATION_OPS_FILE:?}
: ${RELEASE_NAME:?}
: ${STEMCELL_NAME:?}
: ${DEPLOYMENT_NAME:?}

# inputs
pipelines_dir="$( cd $(dirname $0) && cd ../.. && pwd )"
workspace_dir="$( cd ${pipelines_dir} && cd .. && pwd )"
environment_dir="${workspace_dir}/environment"
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

# outputs
manifest_dir="${workspace_dir}/deployment-manifest"

metadata="$( cat ${environment_dir}/metadata )"

${bosh_cli} interpolate "${pipelines_dir}/shared/assets/certification-release/certification.yml" \
  -o "${CERTIFICATION_OPS_FILE}" \
  -v "deployment_name=${DEPLOYMENT_NAME}" \
  -v "release_name=${RELEASE_NAME}" \
  -v "stemcell_name=${STEMCELL_NAME}" \
  -v "bosh_vsphere_vcenter_vlan=${BOSH_VSPHERE_VCENTER_VLAN}" \ # vSphere specific
  -l <( cat <<< "${metadata}" )> "${manifest_dir}/deployment.yml"
