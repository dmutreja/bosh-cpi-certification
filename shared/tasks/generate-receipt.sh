#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh

: ${CPI_RELEASE_NAME:?}
: ${STEMCELL_NAME:?}

BOSH_RELEASE_VERSION=$(cat bosh-release/version)
CPI_RELEASE_VERSION=$(cat cpi-release/version)
STEMCELL_VERSION=$(cat stemcell/version)

timestamp="$(date -u +%Y%m%d%H%M%S)"
contents_hash=$(echo bosh-${BOSH_RELEASE_VERSION}-${CPI_RELEASE_NAME}-${CPI_RELEASE_VERSION}-${STEMCELL_NAME}-${STEMCELL_VERSION} | md5sum | cut -f1 -d ' ')

certify_artifacts \
  bosh $BOSH_RELEASE_VERSION \
  $CPI_RELEASE_NAME $CPI_RELEASE_VERSION \
  $STEMCELL_NAME $STEMCELL_VERSION \
  > certification/${contents_hash}-${timestamp}-receipt.json
