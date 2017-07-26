#!/bin/bash

set -e

docker_dir="$( cd $(dirname $0) && pwd )"

golang_version=${1?"Specify Golang version! e.g 1.8.3"}
golang_sha256=${2?"Specify Golang binary sha256!"}
DOCKER_IMAGE=${DOCKER_IMAGE:-boshcpi/golang}:$golang_version

docker login

echo "Building docker image '$DOCKER_IMAGE' ..."
docker build \
  -t "$DOCKER_IMAGE" \
  --build-arg \
  GOLANG_VERSION=$golang_version \
  GOLANG_SHA256SUM=$golang_sha256 \
  ${docker_dir}

echo "Pushing docker image to '$DOCKER_IMAGE' ..."
docker push "$DOCKER_IMAGE"
