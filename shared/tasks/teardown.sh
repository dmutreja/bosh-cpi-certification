#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

if [ ! -e director-state/director-state.json ]; then
  echo "director-state.json does not exist, skipping..."
  exit 0
fi

if [ -d "director-state/.bosh" ]; then
  # reuse compiled packages
  cp -r director-state/.bosh $HOME/
fi

pushd director-state > /dev/null
  # configuration
  source director.env

  # Don't exit on failure to delete existing deployment
  set +e
    # teardown deployments against BOSH Director
    if [ -n "${DEPLOYMENT_NAME}" ]; then
      time bosh2 -n delete-deployment -d ${DEPLOYMENT_NAME} --force
    fi
    time bosh2 -n clean-up --all
  set -e

  echo "deleting existing BOSH Director VM..."
  bosh2 -n delete-env --vars-store creds.yml -v director_name=bosh director.yml
popd
