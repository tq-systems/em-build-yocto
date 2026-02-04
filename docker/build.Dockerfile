#
# Image with yocto build scripts
#

ARG BASE_REGISTRY
ARG BASE_DOCKER_TAG
FROM ${BASE_REGISTRY}/yocto:${BASE_DOCKER_TAG}

COPY ./docker/usr/local/bin /usr/local/bin
COPY ./docker/opt/energy-manager /opt/energy-manager
