#!/usr/bin/env bash

set -e

: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
: ${RELEASE_NAME:?}
: ${STEMCELL_NAME:?}
: ${AZURE_DNS:?}
: ${DEPLOYMENT_NAME:?}

source pipelines/shared/utils.sh

# inputs
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

release_dir="$( cd $(dirname $0) && cd ../.. && pwd )"
workspace_dir="$( cd ${release_dir} && cd .. && pwd )"
ci_environment_dir="${workspace_dir}/environment"

metadata="$( cat ${ci_environment_dir}/metadata )"

# configuration
: ${DIRECTOR_PIP:=$(   echo ${metadata} | jq --raw-output ".DirectorPublicIP" )}
: ${NETWORK:=$(        echo ${metadata} | jq --raw-output ".Network" )}
: ${SUBNET:=$(         echo ${metadata} | jq --raw-output ".Subnetwork" )}
: ${RESERVED_RANGE:=$( echo ${metadata} | jq --raw-output ".ReservedRange" )}
: ${INTERNAL_CIDR:=$(  echo ${metadata} | jq --raw-output ".InternalCIDR" )}
: ${INTERNAL_GW:=$(    echo ${metadata} | jq --raw-output ".InternalGateway" )}

# outputs
manifest_dir="$(realpath deployment-manifest)"

export BOSH_ENVIRONMENT="${DIRECTOR_PIP}"

cat > "${manifest_dir}/deployment.yml" <<EOF
---
name: ${DEPLOYMENT_NAME}

releases:
  - name: ${RELEASE_NAME}
    version: latest

compilation:
  reuse_compilation_vms: true
  workers: 1
  network: private
  cloud_properties:
    instance_type: Standard_D1

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 3

resource_pools:
  - name: default
    stemcell:
      name: ${STEMCELL_NAME}
      version: latest
    network: private
    cloud_properties:
      instance_type: Standard_D1

networks:
  - name: private
    type: manual
    subnets:
      - range: ${INTERNAL_CIDR}
        gateway: ${INTERNAL_GW}
        cloud_properties:
          virtual_network_name: ${NETWORK}
          subnet_name: ${SUBNET}
        reserved: [${RESERVED_RANGE}]

jobs:
  - name: simple
    template: simple
    instances: 1
    resource_pool: default
    networks:
      - name: private
        default: [dns, gateway]
EOF
