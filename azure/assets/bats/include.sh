#!/usr/bin/env bash

function director_public_ip {
  local metadata=${1:?}
  echo ${metadata} | jq --raw-output ".director_public_ip"
}

function create_bats_env {
  local metadata=${1:?}
  local bat_vcap_password=${2:?}
  local bosh_client_secret=${3:?}
  local stemcell_name=${4:?}

  local director_pip=$( echo ${metadata} | jq --raw-output ".director_public_ip" )

cat <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${director_pip}
export BAT_DNS_HOST=${director_pip}
export BAT_INFRASTRUCTURE=azure
export BAT_NETWORKING=manual
export BAT_VCAP_PRIVATE_KEY="bats-config/shared.pem"
export BAT_VCAP_PASSWORD=${bat_vcap_password}
if [[ "${stemcell_name}" == *"centos-7"* ]]; then
  export BAT_RSPEC_FLAGS="--tag ~raw_ephemeral_storage --tag ~multiple_manual_networks"
else
  export BAT_RSPEC_FLAGS="--tag ~raw_ephemeral_storage"
fi
export BAT_DIRECTOR_USER=admin
export BAT_DIRECTOR_PASSWORD="${bosh_client_secret}"
EOF
}
