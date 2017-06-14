#!/usr/bin/env bash

set -e

: ${BAT_VCAP_PASSWORD:?}
: ${BOSH_CLIENT_SECRET:?}
: ${STEMCELL_NAME:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
release_dir="$( cd $(dirname $0) && cd ../.. && pwd )"
workspace_dir="$( cd ${release_dir} && cd .. && pwd )"
ci_environment_dir="${workspace_dir}/environment"
director_config="${workspace_dir}/director-config"
bats_dir="${workspace_dir}/bats"
director_state_dir="${workspace_dir}/director-state"

: ${METADATA_FILE:=${ci_environment_dir}/metadata}
if [ ! -f ${METADATA_FILE} ]; then
  echo -e "METADATA_FILE '${METADATA_FILE}' does not exist"
  exit 1
fi
metadata="$( cat ${METADATA_FILE} )"

# configuration
: ${DIRECTOR_PIP:=$(           echo ${metadata} | jq --raw-output ".DirectorPublicIP" )}
: ${VIRTUAL_NETWORK_NAME:=$(   echo ${metadata} | jq --raw-output ".Network" )}
: ${BATS_PIP:=$(               echo ${metadata} | jq --raw-output ".BATsPublicIP" )}
: ${RESOURCE_GROUP_NAME:=$(    echo ${metadata} | jq --raw-output ".ResourceGroupName" )}
: ${DEFAULT_SECURITY_GROUP:=$( echo ${metadata} | jq --raw-output ".DefaultSecurityGroup" )}
# BATs Network
: ${BATS_NAME:=$(           echo ${metadata} | jq --raw-output ".BATsNetwork.Name" )}
: ${BATS_CIDR:=$(           echo ${metadata} | jq --raw-output ".BATsNetwork.CIDR" )}
: ${BATS_GW:=$(             echo ${metadata} | jq --raw-output ".BATsNetwork.Gateway" )}
: ${BATS_RESERVED_RANGE:=$( echo ${metadata} | jq --raw-output ".BATsNetwork.ReservedRange" )}
: ${BATS_STATIC_RANGE:=$(   echo ${metadata} | jq --raw-output ".BATsNetwork.StaticRange" )}
: ${BATS_STATIC_IP:=$(      echo ${metadata} | jq --raw-output ".BATsNetwork.StaticIP" )}
: ${BATS_STATIC_IP_2:=$(    echo ${metadata} | jq --raw-output ".BATsNetwork.StaticIP_2" )}
# BATs Seconds Network
: ${BATS_SECOND_NAME:=$(           echo ${metadata} | jq --raw-output ".BATsSecondNetwork.Name" )}
: ${BATS_SECOND_CIDR:=$(           echo ${metadata} | jq --raw-output ".BATsSecondNetwork.CIDR" )}
: ${BATS_SECOND_GW:=$(             echo ${metadata} | jq --raw-output ".BATsSecondNetwork.Gateway" )}
: ${BATS_SECOND_RESERVED_RANGE:=$( echo ${metadata} | jq --raw-output ".BATsSecondNetwork.ReservedRange" )}
: ${BATS_SECOND_STATIC_RANGE:=$(   echo ${metadata} | jq --raw-output ".BATsSecondNetwork.StaticRange" )}
: ${BATS_SECOND_STATIC_IP:=$(      echo ${metadata} | jq --raw-output ".BATsSecondNetwork.StaticIP" )}

# outputs
output_dir="${workspace_dir}/bats-config"
bats_spec="${output_dir}/bats-config.yml"
bats_env="${output_dir}/bats.env"
ssh_key="${output_dir}/shared.pem"

# env file generation
cat > "${bats_env}" <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${DIRECTOR_PIP}
export BAT_DNS_HOST=${DIRECTOR_PIP}
export BAT_INFRASTRUCTURE=azure
export BAT_NETWORKING=manual
export BAT_VCAP_PRIVATE_KEY="bats-config/shared.pem"
export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
if [[ "${STEMCELL_NAME}" == *"centos-7"* ]]; then
  export BAT_RSPEC_FLAGS="--tag ~raw_ephemeral_storage --tag ~multiple_manual_networks"
else
  export BAT_RSPEC_FLAGS="--tag ~raw_ephemeral_storage"
fi
export BAT_DIRECTOR_USER=admin
export BAT_DIRECTOR_PASSWORD="${BOSH_CLIENT_SECRET}"
EOF

pushd "${bats_dir}" > /dev/null
  ./write_gemfile
  bundle install
  bundle exec bosh -n target "${DIRECTOR_PIP}"
  BOSH_UUID="$(bundle exec bosh status --uuid)"
popd > /dev/null

# BATs spec generation
cat > "${bats_spec}" <<EOF
---
cpi: azure
properties:
  uuid: ${BOSH_UUID}
  stemcell:
    name: ${STEMCELL_NAME}
    version: latest
  vip: ${BATS_PIP}
  pool_size: 1
  instances: 1
  second_static_ip: ${BATS_STATIC_IP_2}
  networks:
  - name: default
    type: manual
    static_ip: ${BATS_STATIC_IP}
    cloud_properties:
      resource_group_name: ${RESOURCE_GROUP_NAME}
      virtual_network_name: ${VIRTUAL_NETWORK_NAME}
      subnet_name: ${BATS_NAME}
      security_group: ${DEFAULT_SECURITY_GROUP}
    cidr: ${BATS_CIDR}
    reserved: [${BATS_RESERVED_RANGE}]
    static: [${BATS_STATIC_RANGE}]
    gateway: ${BATS_GW}
  - name: second
    type: manual
    static_ip: ${BATS_SECOND_STATIC_IP}
    cloud_properties:
      resource_group_name: ${RESOURCE_GROUP_NAME}
      virtual_network_name: ${VIRTUAL_NETWORK_NAME}
      subnet_name: ${BATS_SECOND_NAME}
      security_group: ${DEFAULT_SECURITY_GROUP}
    cidr: ${BATS_SECOND_CIDR}
    reserved: [${BATS_SECOND_RESERVED_RANGE}]
    static: [${BATS_SECOND_STATIC_RANGE}]
    gateway: ${BATS_SECOND_GW}
  - name: static
    type: vip
    cloud_properties:
      resource_group_name: ${RESOURCE_GROUP_NAME}
  key_name: bosh
EOF

cp ${director_state_dir}/shared.pem ${ssh_key}
