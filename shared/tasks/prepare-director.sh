#!/usr/bin/env bash

set -e

: ${BOSH_CLIENT_SECRET:?}
: ${DIRECTOR_VARS_FILE:?}
: ${INFRASTRUCTURE:?}
: ${INCLUDE_FILE:?}
: ${USE_REDIS:?}

source $INCLUDE_FILE

# inputs
pipelines_dir="$( cd $(dirname $0) && cd ../.. && pwd )"
workspace_dir="$( cd ${pipelines_dir} && cd .. && pwd )"
environment_dir="${workspace_dir}/environment"
bosh_deployment="${workspace_dir}/bosh-deployment"
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

# outputs
output_dir="${workspace_dir}/director-config"

metadata="$( cat ${environment_dir}/metadata )"
redis_ops=""
if [ "${USE_REDIS}" == true ]; then
  redis_ops="-o ${pipelines_dir}/shared/assets/ops/redis.yml"
fi

cat > "${output_dir}/director.env" <<EOF
#!/usr/bin/env bash

export BOSH_ENVIRONMENT=$( director_public_ip "${metadata}" )
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET}
EOF

${bosh_cli} int \
  -o ${bosh_deployment}/${INFRASTRUCTURE}/cpi.yml \
  -o ${bosh_deployment}/powerdns.yml \
  -o ${bosh_deployment}/jumpbox-user.yml \
  -o ${pipelines_dir}/shared/assets/ops/custom-releases.yml \
  -o ${pipelines_dir}/${INFRASTRUCTURE}/assets/ops/custom-cpi-release.yml \
  $( echo ${redis_ops} ) \
  $( echo ${OPTIONAL_OPS_FILE} ) \
  -v bosh_release_uri="file://$(echo bosh-release/*.tgz)" \
  -v cpi_release_uri="file://$(echo cpi-release/*.tgz)" \
  -v stemcell_uri="file://$(echo stemcell/*.tgz)" \
  -l <( echo "${DIRECTOR_VARS_FILE}" ) \
  ${bosh_deployment}/bosh.yml > /tmp/director.yml

${bosh_cli} int \
  -l "${environment_dir}/metadata" \
  /tmp/director.yml > "${output_dir}/director.yml"
