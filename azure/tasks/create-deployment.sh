#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh

: ${RELEASE_NAME:?}
: ${DEPLOYMENT_NAME:?}

# inputs
release_dir="$( cd $(dirname $0) && cd ../.. && pwd )"
workspace_dir="$( cd ${release_dir} && cd .. && pwd )"
manifest_dir="${workspace_dir}/deployment-manifest"
deployment_release="${workspace_dir}/pipelines/shared/assets/certification-release"
director_state_dir="${workspace_dir}/director-state"

stemcell_path=$(realpath stemcell/*.tgz)
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

source "${director_state_dir}/director.env"
export BOSH_CA_CERT="${director_state_dir}/ca_cert.pem"

pushd ${deployment_release}
  time $bosh_cli -n create-release --force --name ${RELEASE_NAME}
  time $bosh_cli -n upload-release
popd

time $bosh_cli -n upload-stemcell ${stemcell_path}
time $bosh_cli -n deploy -d ${DEPLOYMENT_NAME} ${manifest_dir}/deployment.yml
