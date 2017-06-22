#!/usr/bin/env bash

function director_public_ip {
  local metadata=${1:?}
  bosh2 int <(cat <<< "${metadata}") --path /director_eip
}

function create_bats_env {
  local metadata=${1:?}

cat <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=$( bosh2 int <(cat <<< "${metadata}") --path /director_eip )
export BAT_DNS_HOST=$( bosh2 int <(cat <<< "${metadata}") --path /director_eip )
export BAT_INFRASTRUCTURE=aws
export BAT_NETWORKING=manual
export BAT_VIP=$( bosh2 int <(cat <<< "${metadata}") --path /bats_eip )
export BAT_SUBNET_ID=$( bosh2 int <(cat <<< "${metadata}") --path /subnet_id )
export BAT_SECURITY_GROUP_NAME=$( bosh2 int <(cat <<< "${metadata}") --path /security_group_name )
export BAT_RSPEC_FLAGS="--tag ~multiple_manual_networks --tag ~root_partition"
EOF
}
