#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh

: ${BOSH_VSPHERE_VCENTER:?}
: ${BOSH_VSPHERE_VCENTER_USER:?}
: ${BOSH_VSPHERE_VCENTER_PASSWORD:?}
: ${BOSH_VSPHERE_VERSION:?}
: ${BOSH_VSPHERE_VCENTER_DC:?}
: ${BOSH_VSPHERE_VCENTER_CLUSTER:?}
: ${BOSH_VSPHERE_VCENTER_RESOURCE_POOL:?}
: ${BOSH_VSPHERE_VCENTER_VM_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_DATASTORE:?}
: ${BOSH_VSPHERE_VCENTER_DISK_PATH:?}
: ${BOSH_VSPHERE_VCENTER_VLAN:?}
: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
: ${USE_REDIS:=false}

# inputs
# paths will be resolved in a separate task so use relative paths
BOSH_RELEASE_URI="file://$(echo bosh-release/*.tgz)"
CPI_RELEASE_URI="file://$(echo cpi-release/*.tgz)"
STEMCELL_URI="file://$(echo stemcell/*.tgz)"

# outputs
output_dir="$(realpath director-config)"

bosh_deployment=$(realpath bosh-deployment)
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

# environment
env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
echo Using environment: \'${env_name}\'
: ${DIRECTOR_IP:=$(                  env_attr "${metadata}" "directorIP" )}
: ${BOSH_VSPHERE_VCENTER_CIDR:=$(    env_attr "${network1}" "vCenterCIDR" )}
: ${BOSH_VSPHERE_VCENTER_GATEWAY:=$( env_attr "${network1}" "vCenterGateway" )}
: ${BOSH_VSPHERE_DNS:=$(             env_attr "${metadata}" "DNS" )}

redis_ops=""
if [ "${USE_REDIS}" == true ]; then
  redis_ops="--ops-file pipelines/shared/assets/ops/redis.yml"
fi

# env file generation
cat > "${output_dir}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_ENVIRONMENT="${DIRECTOR_IP}"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET}
EOF

cat > /tmp/vcenter_creds.yml <<EOF
---
vcenter_ip: ${BOSH_VSPHERE_VCENTER}
vcenter_user: ${BOSH_VSPHERE_VCENTER_USER}
vcenter_password: ${BOSH_VSPHERE_VCENTER_PASSWORD}
vcenter_dc: ${BOSH_VSPHERE_VCENTER_DC}
vcenter_vms: ${BOSH_VSPHERE_VCENTER_VM_FOLDER}
vcenter_templates: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER}
vcenter_ds: ${BOSH_VSPHERE_VCENTER_DATASTORE}
vcenter_disks: ${BOSH_VSPHERE_VCENTER_DISK_PATH}
vcenter_cluster: ${BOSH_VSPHERE_VCENTER_CLUSTER}
vcenter_rp: ${BOSH_VSPHERE_VCENTER_RESOURCE_POOL}
network_name: ${BOSH_VSPHERE_VCENTER_VLAN}
internal_gw: ${BOSH_VSPHERE_VCENTER_GATEWAY}
internal_cidr: ${BOSH_VSPHERE_VCENTER_CIDR}
internal_ip: ${DIRECTOR_IP}
admin_password: ${BOSH_CLIENT_SECRET}
hm_password: hm-password
redis_password: redis-password
dns_recursor_ip: ${BOSH_VSPHERE_DNS}
EOF

${bosh_cli} interpolate \
  --ops-file ${bosh_deployment}/vsphere/cpi.yml \
  --ops-file ${bosh_deployment}/vsphere/resource-pool.yml \
  --ops-file ${bosh_deployment}/powerdns.yml \
  --ops-file pipelines/shared/assets/ops/custom-releases.yml \
  --ops-file pipelines/vsphere/assets/ops/custom-releases.yml \
  $(echo ${redis_ops}) \
  -v bosh_release_uri="${BOSH_RELEASE_URI}" \
  -v cpi_release_uri="${CPI_RELEASE_URI}" \
  -v stemcell_uri="${STEMCELL_URI}" \
  -l /tmp/vcenter_creds.yml \
  ${bosh_deployment}/bosh.yml > "${output_dir}/director.yml"
