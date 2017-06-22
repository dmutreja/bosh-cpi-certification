#!/usr/bin/env bash

set -e

# environment
: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}
: ${PUBLIC_KEY_NAME:?}
: ${PRIVATE_KEY_DATA:?}

# inputs
BOSH_RELEASE_URI="file://$(echo bosh-release/*.tgz)"
CPI_RELEASE_URI="file://$(echo cpi-release/*.tgz)"
STEMCELL_URI="file://$(echo stemcell/*.tgz)"

# outputs
output_dir="$(realpath director-config)"

bosh_deployment=$(realpath bosh-deployment)

source pipelines/shared/utils.sh
source pipelines/aws/utils.sh

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

# configuration
: ${SECURITY_GROUP:=$(       aws ec2 describe-security-groups --group-ids $(stack_info "SecurityGroupID") | jq -r '.SecurityGroups[] .GroupName' )}
: ${DIRECTOR_EIP:=$(         stack_info "DirectorEIP" )}
: ${SUBNET_ID:=$(            stack_info "PublicSubnetID" )}
: ${AVAILABILITY_ZONE:=$(    stack_info "AvailabilityZone" )}
: ${AWS_NETWORK_CIDR:=$(     stack_info "PublicCIDR" )}
: ${AWS_NETWORK_GATEWAY:=$(  stack_info "PublicGateway" )}
: ${AWS_NETWORK_DNS:=$(      stack_info "DNS" )}
: ${DIRECTOR_STATIC_IP:=$(   stack_info "DirectorStaticIP" )}
: ${BLOBSTORE_BUCKET_NAME:=$(stack_info "BlobstoreBucketName")}
: ${IAM_INSTANCE_PROFILE:=$(stack_info "IAMInstanceProfile")}

# keys
shared_key="shared.pem"
echo "${PRIVATE_KEY_DATA}" > "${output_dir}/${shared_key}"

# env file generation
cat > "${output_dir}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_ENVIRONMENT="${DIRECTOR_EIP}"
export BOSH_CLIENT=${BOSH_CLIENT}
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET}
EOF

manifest_filename="${output_dir}/director.yml"

cat > /tmp/aws-ops.yml <<EOF
---
- type: replace
  path: /resource_pools/name=vms/cloud_properties/iam_instance_profile?
  value: ((iam_instance_profile))

- type: replace
  path: /instance_groups/name=bosh/properties/aws/default_iam_instance_profile?
  value: ((iam_instance_profile))
EOF

cat > /tmp/aws_creds.yml <<EOF
---
iam_instance_profile: ${IAM_INSTANCE_PROFILE}
private_key: ${shared_key}
access_key_id: ${AWS_ACCESS_KEY}
secret_access_key: ${AWS_SECRET_KEY}
default_key_name: ${PUBLIC_KEY_NAME}
default_security_groups: [${SECURITY_GROUP}]
region: ${AWS_REGION_NAME}
az: ${AVAILABILITY_ZONE}
internal_gw: ${AWS_NETWORK_GATEWAY}
internal_ip: ${DIRECTOR_STATIC_IP}
internal_cidr: ${AWS_NETWORK_CIDR}
external_ip: ${DIRECTOR_EIP}
subnet_id: ${SUBNET_ID}
admin_password: ${BOSH_CLIENT_SECRET}
redis_password: redis-password
dns_recursor_ip: 10.0.0.2
EOF

bosh2 interpolate \
  --ops-file ${bosh_deployment}/aws/cpi.yml \
  --ops-file ${bosh_deployment}/powerdns.yml \
  --ops-file pipelines/shared/assets/ops/custom-releases.yml \
  --ops-file pipelines/aws/assets/ops/custom-releases.yml \
  --ops-file ${bosh_deployment}/external-ip-with-registry-not-recommended.yml \
  --ops-file /tmp/aws-ops.yml \
  -v bosh_release_uri="${BOSH_RELEASE_URI}" \
  -v cpi_release_uri="${CPI_RELEASE_URI}" \
  -v stemcell_uri="${STEMCELL_URI}" \
  -l /tmp/aws_creds.yml \
  ${bosh_deployment}/bosh.yml > "${output_dir}/director.yml"
