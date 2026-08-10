#
# Yocto build image with standardized Makefiles and build scripts
#

ARG YOCTO_REGISTRY
ARG BUILD_TAG
FROM ${YOCTO_REGISTRY}/base:${BUILD_TAG}

COPY ./docker/usr/local/bin /usr/local/bin
COPY ./docker/opt/energy-manager /opt/energy-manager

ARG DOCKER_USER
USER ${DOCKER_USER}
