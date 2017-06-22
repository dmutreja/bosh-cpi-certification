#!/usr/bin/env bash

# Oportunistically configure bosh2 for use
bosh_src="$(realpath bosh-cli/*bosh-cli-* 2>/dev/null)"
if [[ $? -eq 0 ]]; then
  export bosh_cli="/usr/local/bin/bosh2"
  mv "${bosh_src}" "${bosh_cli}"
  chmod +x "${bosh_cli}"
  echo "bosh2 installed at ${bosh_cli}"
else
  echo "bosh2 not installed because bosh-cli input is not available"
fi
