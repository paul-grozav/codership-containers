#!/bin/sh -eu
#
# Build and publish Docker image to Cdership repo
#
# Needs the following parameters:
#
# REPO= e.g. 'mysql-galera-test' - product name
# TAG= e.g. '8.0.34'             - image tag
# MYSQL_RPM_VERSION= e.g. 8.0.34-26.15
# DOCKER_USER=
# DOCKER_PSWD=

docker buildx build --build-arg MYSQL_RPM_VERSION=${MYSQL_RPM_VERSION} \
       --tag codership/${REPO}:${TAG} .

docker login --username ${DOCKER_USER} --password ${DOCKER_PSWD} # https://login.docker.com
docker push codership/${REPO}:${TAG}
