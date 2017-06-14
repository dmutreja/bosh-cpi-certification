#!/bin/bash

set -e

docker_dir="$( cd $(dirname $0) && pwd )"

DOCKER_IMAGE=${DOCKER_IMAGE:-boshcpi/cpi-certification}

docker login

echo "Building docker image..."
docker build -t $DOCKER_IMAGE ${docker_dir}

echo "Pushing docker image to '$DOCKER_IMAGE'..."
docker push $DOCKER_IMAGE
