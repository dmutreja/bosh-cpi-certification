#!/usr/bin/env bash

function setup_bosh_cli() {
  bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
  chmod +x $bosh_cli
  mv $bosh_cli /usr/local/bin/bosh2
}
