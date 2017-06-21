#!/usr/bin/env bash

function setup_bosh_cli() {
  bosh_cli=$(realpath bosh-cli/*bosh-cli-* 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    chmod +x $bosh_cli
    mv $bosh_cli /usr/local/bin/bosh2
  fi
}

setup_bosh_cli
