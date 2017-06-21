#!/usr/bin/env bash

set -e

: ${INFRASTRUCTURE:?}
: ${BAT_VCAP_PASSWORD:?}
: ${BOSH_CLIENT_SECRET:?}
: ${STEMCELL_NAME:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7
setup_bosh_cli

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

[[ -f director-state/shared.pem ]] && cp director-state/shared.pem bats-config/shared.pem

create_bats_env "${metadata}" "${BAT_VCAP_PASSWORD}" "${BOSH_CLIENT_SECRET}" "${STEMCELL_NAME}" > bats-config/bats.env

bosh2 interpolate pipelines/${INFRASTRUCTURE}/assets/bats/bats-spec.yml \
  -v "bosh_uuid=${bosh_uuid}" \
  -v "stemcell_name=${STEMCELL_NAME}" \
  -l environment/metadata > bats-config/bats-config.yml
