#!/usr/bin/env bash

function director_public_ip {
  local metadata=${1:?}
  echo ${metadata} | jq --raw-output ".directorIP"
}

function create_bats_env {
  local metadata=${1:?}
  local bat_vcap_password=${2:?}
  local bosh_client_secret=${3:?}
  local stemcell_name=${4:?}

  local director_pip=$( director_public_ip ${metadata} )

cat <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${director_pip}
export BAT_DNS_HOST=${director_pip}
export BAT_INFRASTRUCTURE=vsphere
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD=${bat_vcap_password}
export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~dynamic_networking --tag ~root_partition --tag ~raw_ephemeral_storage"
export BAT_DIRECTOR_USER=admin
export BAT_DIRECTOR_PASSWORD="${bosh_client_secret}"
EOF
}
