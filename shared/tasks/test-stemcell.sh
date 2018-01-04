#!/usr/bin/env bash

set -eu

source pipelines/shared/utils.sh
source director-state/director.env

creds_path /jumpbox_ssh/private_key > /tmp/jumpbox_private_key
chmod 600 /tmp/jumpbox_private_key
export BOSH_GW_PRIVATE_KEY=/tmp/jumpbox_private_key

export SYSLOG_RELEASE_PATH=$(realpath syslog-release/*.tgz)
export OS_CONF_RELEASE_PATH=$(realpath os-conf-release/*.tgz)
export STEMCELL_PATH=$(realpath stemcell/*.tgz)
export BOSH_stemcell_version=\"$(realpath stemcell/version | xargs -n 1 cat)\"

pushd bosh-linux-stemcell-builder
  export PATH=/usr/local/go/bin:$PATH
  export GOPATH=$(pwd)

  pushd src/github.com/cloudfoundry/stemcell-acceptance-tests
    ./bin/test-smoke $package
  popd
popd
