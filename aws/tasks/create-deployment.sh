#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source pipelines/aws/utils.sh

: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
: ${RELEASE_NAME:?}
: ${DEPLOYMENT_NAME:?}
: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

# inputs
manifest_dir=$(realpath deployment-manifest)
director_state=$(realpath director-state)
deployment_release=$(realpath pipelines/shared/assets/certification-release)
stemcell_dir=$(realpath stemcell)

# configuration
: ${DIRECTOR_IP:=$( stack_info "DirectorEIP" )}
export BOSH_CA_CERT="${director_state}/ca_cert.pem"

export BOSH_ENVIRONMENT="${DIRECTOR_IP}"

pushd ${deployment_release}
  time bosh2 -n create-release --force --name ${RELEASE_NAME}
  time bosh2 -n upload-release
popd

time bosh2 -n upload-stemcell ${stemcell_dir}/*.tgz
time bosh2 -n deploy -d ${DEPLOYMENT_NAME} ${manifest_dir}/deployment.yml
