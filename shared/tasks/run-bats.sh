#!/usr/bin/env bash

set -e

: ${INFRASTRUCTURE:?}
: ${STEMCELL_NAME:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7
# Override this to alter metadata before interpolation
function transform_metadata() {
  cat
}
source pipelines/${INFRASTRUCTURE}/assets/bats/include.sh

metadata="$( cat environment/metadata )"

mkdir -p bats-config
create_bats_env "${metadata}" "${BAT_VCAP_PASSWORD}" "${BOSH_CLIENT_SECRET}" "${STEMCELL_NAME}" > bats-config/bats.env

bosh2 int pipelines/${INFRASTRUCTURE}/assets/bats/bats-spec.yml \
  -v "stemcell_name=${STEMCELL_NAME}" \
  -l environment/metadata > bats-config/bats-config.yml

export BOSH_ENVIRONMENT="$( state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null )"
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$( creds_path /admin_password )"
export BOSH_CA_CERT="$( creds_path /director_ssl/ca )"
export BOSH_GW_HOST="$( state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null )"
export BOSH_GW_USER="jumpbox"

export BAT_PRIVATE_KEY="$( creds_path /jumpbox_ssh/private_key )"
export BAT_DNS_HOST="$( state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null )"
export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
export BAT_BOSH_CLI=$(realpath bosh-cli/*bosh-cli-*)

ssh_key_path=/tmp/bat_private_key
echo "$BAT_PRIVATE_KEY" > $ssh_key_path
chmod 600 $ssh_key_path
export BOSH_GW_PRIVATE_KEY=$ssh_key_path

# source specific IaaS specific BATs environment variables
source bats-config/bats.env

pushd bats
  bundle install
  bundle exec rspec spec $BAT_RSPEC_FLAGS
popd
