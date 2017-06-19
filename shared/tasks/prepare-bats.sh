#!/usr/bin/env bash

set -e

: ${BAT_VCAP_PASSWORD:?}
: ${BOSH_CLIENT_SECRET:?}
: ${STEMCELL_NAME:?}
: ${INCLUDE_FILE:?}
: ${BATS_SPEC:?}

source /etc/profile.d/chruby.sh
chruby 2.1.7

# Override this to alter metadata before interpolation
function transform_metadata() {
  cat
}
source $INCLUDE_FILE

# inputs
pipelines_dir="$( cd $(dirname $0) && cd ../.. && pwd )"
workspace_dir="$( cd ${pipelines_dir} && cd .. && pwd )"
environment_dir="${workspace_dir}/environment"
director_shared_pem="${workspace_dir}/director-state/shared.pem"
bats_dir="${workspace_dir}/bats"
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)

# outputs
output_dir="${workspace_dir}/bats-config"

metadata="$( cat ${environment_dir}/metadata )"

pushd "${bats_dir}" > /dev/null
  ./write_gemfile
  bundle install
  bundle exec bosh -n target $( director_public_ip "${metadata}" )
  BOSH_UUID="$(bundle exec bosh status --uuid)"
popd > /dev/null

[[ -f ${director_shared_pem} ]] && cp ${director_shared_pem} "${output_dir}/shared.pem"

create_bats_env "${metadata}" "${BAT_VCAP_PASSWORD}" "${STEMCELL_NAME}" "${BOSH_CLIENT_SECRET}" > "${output_dir}/bats.env"

${bosh_cli} interpolate ""${BATS_SPEC}"" \
  -v "bosh_uuid=${bosh_uuid}" \
  -v "stemcell_name=${STEMCELL_NAME}" \
  -l <( transform_metadata <<< "${metadata}" ) > "${output_dir}/bats-config.yml"
