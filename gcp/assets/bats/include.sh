#!/usr/bin/env bash

function director_public_ip {
  local metadata=${1:?}
  echo ${metadata} | jq --raw-output ".external_ip"
}

function create_bats_env {
  local metadata=${1:?}
  local director_external_ip=$( echo ${metadata} | jq --raw-output ".external_ip" )

cat <<EOF
#!/usr/bin/env bash
export BAT_DIRECTOR=${director_external_ip}
export BAT_DNS_HOST=${director_external_ip}
export BAT_INFRASTRUCTURE=gcp
export BAT_NETWORKING=dynamic
export BAT_RSPEC_FLAGS="--tag ~multiple_manual_networks --tag ~raw_ephemeral_storage --tag ~changing_static_ip"
EOF
}
