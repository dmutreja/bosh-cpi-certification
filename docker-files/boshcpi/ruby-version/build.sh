#!/bin/bash

set -e

docker_dir="$( cd $(dirname $0) && pwd )"

ruby_version=${1?"Specify Ruby version! e.g 2.2.6"}
DOCKER_IMAGE=${DOCKER_IMAGE:-boshcpi/ruby}:$ruby_version

docker login

echo "Building docker image '$DOCKER_IMAGE' ..."
docker build -t "$DOCKER_IMAGE" --build-arg RUBY_VERSION=$ruby_version ${docker_dir}

echo "Pushing docker image to '$DOCKER_IMAGE' ..."
docker push "$DOCKER_IMAGE"
