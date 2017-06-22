#!/usr/bin/env bash

set -e

: ${AWS_ACCESS_KEY_ID:?}
: ${AWS_SECRET_ACCESS_KEY:?}
: ${AWS_DEFAULT_REGION:?}
: ${AWS_STACK_NAME:?}
: ${PUBLIC_KEY_NAME:?}

source pipelines/shared/utils.sh
source pipelines/aws/utils.sh

cat > environment/metadata <<EOF
security_group_name: $(    aws ec2 describe-security-groups --group-ids $(stack_info "SecurityGroupID") | jq -r '.SecurityGroups[] .GroupName' )
director_eip: $(           stack_info "DirectorEIP" )
bats_eip: $(               stack_info "DeploymentEIP" )
subnet_id: $(              stack_info "PublicSubnetID" )
availability_zone: $(      stack_info "AvailabilityZone" )
network_cidr: $(           stack_info "PublicCIDR" )
network_gateway: $(        stack_info "PublicGateway" )
network_reserved_range: $( stack_info "ReservedRange" )
network_static_range: $(   stack_info "StaticRange" )
network_static_ip_1: $(    stack_info "StaticIP1" )
network_static_ip_2: $(    stack_info "StaticIP2" )
public_key_name: ${PUBLIC_KEY_NAME}
EOF
