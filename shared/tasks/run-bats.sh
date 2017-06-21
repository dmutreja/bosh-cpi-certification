#!/usr/bin/env bash

set -e

: ${INFRASTRUCTURE:?}
: ${BAT_VCAP_PASSWORD:?}
: ${BOSH_CLIENT_SECRET:?}
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

pushd bats > /dev/null
  ./write_gemfile
  bundle install
  bundle exec bosh -n target $( director_public_ip "${metadata}" )
  bosh_uuid="$(bundle exec bosh status --uuid)"
popd > /dev/null

mkdir bats-config
create_bats_env "${metadata}" "${BAT_VCAP_PASSWORD}" "${BOSH_CLIENT_SECRET}" "${STEMCELL_NAME}" > bats-config/bats.env

bosh2 interpolate pipelines/${INFRASTRUCTURE}/assets/bats/bats-spec.yml \
  -v "bosh_uuid=${bosh_uuid}" \
  -v "stemcell_name=${STEMCELL_NAME}" \
  -l environment/metadata > bats-config/bats-config.yml

mkdir -p $HOME/.ssh
cat > $HOME/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

if [ -f director-state/shared.pem ]; then
  cp director-state/shared.pem bats-config/shared.pem
  export BAT_VCAP_PRIVATE_KEY="bats-config/shared.pem"
  ssh_key_path="$(realpath ${BAT_VCAP_PRIVATE_KEY})"
  chmod go-r ${ssh_key_path}
  eval $(ssh-agent)
  ssh-add ${ssh_key_path}
fi
export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
export BAT_DIRECTOR_USER=admin
export BAT_DIRECTOR_PASSWORD="${BOSH_CLIENT_SECRET}"
export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
source bats-config/bats.env

pushd bats
  ./write_gemfile
  bundle install
  bundle exec rspec spec ${BAT_RSPEC_FLAGS}
popd
