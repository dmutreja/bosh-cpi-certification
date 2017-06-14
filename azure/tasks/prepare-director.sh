#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh

: ${AZURE_TENANT_ID:?}
: ${AZURE_CLIENT_ID:?}
: ${AZURE_CLIENT_SECRET:?}
: ${AZURE_ENVIRONMENT:?}
: ${AZURE_SUBSCRIPTION_ID:?}
: ${BOSH_CLIENT_SECRET:?}
: ${AZURE_DNS:?}
: ${USE_REDIS:?}

# inputs
release_dir="$( cd $(dirname $0) && cd ../.. && pwd )"
workspace_dir="$( cd ${release_dir} && cd .. && pwd )"
ci_environment_dir="${workspace_dir}/environment"
bosh_deployment="${workspace_dir}/bosh-deployment"
certification="${workspace_dir}/pipelines"

: ${METADATA_FILE:=${ci_environment_dir}/metadata}
if [ ! -f ${METADATA_FILE} ]; then
  echo -e "METADATA_FILE '${METADATA_FILE}' does not exist"
  exit 1
fi

metadata="$( cat ${METADATA_FILE} )"

# inputs
# paths will be resolved in a separate task so use relative paths
BOSH_RELEASE_URI="file://$( echo bosh-release/*.tgz )"
CPI_RELEASE_URI="file://$( echo cpi-release/*.tgz )"
STEMCELL_URI="file://$( echo stemcell/*.tgz )"

# configuration
: ${DIRECTOR_PIP:=$(           echo ${metadata} | jq --raw-output ".DirectorPublicIP" )}
: ${NETWORK:=$(                echo ${metadata} | jq --raw-output ".Network" )}
: ${SUBNET:=$(                 echo ${metadata} | jq --raw-output ".Subnetwork" )}
: ${RESOURCE_GROUP_NAME:=$(    echo ${metadata} | jq --raw-output ".ResourceGroupName" )}
: ${STORAGE_ACCOUNT_NAME:=$(   echo ${metadata} | jq --raw-output ".StorageAccountName" )}
: ${DEFAULT_SECURITY_GROUP:=$( echo ${metadata} | jq --raw-output ".DefaultSecurityGroup" )}
: ${INTERNAL_CIDR:=$(          echo ${metadata} | jq --raw-output ".InternalCIDR" )}
: ${INTERNAL_GW:=$(            echo ${metadata} | jq --raw-output ".InternalGateway" )}

# outputs
output_dir="${workspace_dir}/director-config"

bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

redis_ops=""
if [ "${USE_REDIS}" == true ]; then
  redis_ops="--ops-file pipelines/shared/assets/ops/redis.yml"
fi

# env file generation
cat > "${output_dir}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_ENVIRONMENT="${DIRECTOR_PIP}"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET}
EOF

cat > /tmp/azure_creds.yml <<EOF
---
external_ip: ${DIRECTOR_PIP}
vnet_name: ${NETWORK}
subnet_name: ${SUBNET}
internal_ip: 10.0.0.6
environment: ${AZURE_ENVIRONMENT}
subscription_id: ${AZURE_SUBSCRIPTION_ID}
tenant_id: ${AZURE_TENANT_ID}
client_id: ${AZURE_CLIENT_ID}
client_secret: ${AZURE_CLIENT_SECRET}
resource_group_name: ${RESOURCE_GROUP_NAME}
storage_account_name: ${STORAGE_ACCOUNT_NAME}
default_security_group: ${DEFAULT_SECURITY_GROUP}
internal_cidr: ${INTERNAL_CIDR}
internal_gw: ${INTERNAL_GW}
director_name: bosh-certification
admin_password: ${BOSH_CLIENT_SECRET}
dns_recursor_ip: ${AZURE_DNS}
redis_password: redis-password
EOF

${bosh_cli} interpolate \
  --ops-file ${bosh_deployment}/azure/cpi.yml \
  --ops-file ${bosh_deployment}/azure/custom-environment.yml \
  --ops-file ${bosh_deployment}/powerdns.yml \
  --ops-file ${bosh_deployment}/jumpbox-user.yml \
  --ops-file ${bosh_deployment}/external-ip-with-registry-not-recommended.yml \
  --ops-file ${certification}/shared/assets/ops/custom-releases.yml \
  --ops-file ${certification}/azure/assets/ops/custom-release.yml \
  $(echo ${redis_ops}) \
  -v bosh_release_uri="${BOSH_RELEASE_URI}" \
  -v cpi_release_uri="${CPI_RELEASE_URI}" \
  -v stemcell_uri="${STEMCELL_URI}" \
  -l /tmp/azure_creds.yml \
  ${bosh_deployment}/bosh.yml > "${output_dir}/director.yml"
