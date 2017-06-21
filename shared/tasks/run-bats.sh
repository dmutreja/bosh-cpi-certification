#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

# preparation
export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
source bats-config/bats.env

# disable host key checking for deployed VMs
mkdir -p $HOME/.ssh
cat > $HOME/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

if [ -n "${BAT_VCAP_PRIVATE_KEY}" ]; then
  ssh_key_path="$(realpath ${BAT_VCAP_PRIVATE_KEY})"
  chmod go-r ${ssh_key_path}
  eval $(ssh-agent)
  ssh-add ${ssh_key_path}
fi

pushd bats
  ./write_gemfile
  bundle install
  bundle exec rspec spec ${BAT_RSPEC_FLAGS}
popd
