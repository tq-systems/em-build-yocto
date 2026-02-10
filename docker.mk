# Copyright (c) 2025 TQ-Systems GmbH <license@tq-group.com>
# D-82229 Seefeld, Germany. All rights reserved.
# Author:
#   Christoph Krutz


# Default string, if no docker registry is defined
LOCAL_YOCTO = local/em/yocto
YOCTO_REGISTRY ?= ${LOCAL_YOCTO}

# Default strings for dependent base image(s)
BASE_REGISTRY ?= local/em/base
BASE_DOCKER_TAG ?= latest

# The if-clause also applies if an empty string is set in CI pipelines
ifeq ($(strip ${BUILD_TAG}),)
	BUILD_TAG := latest
endif

IMAGE ?= build
COMPOSE_FILE ?= -f docker-compose.yml
# Additional docker-compose build options may be set (e.g. --no-cache)
BUILD_ARGS ?=

# .env file is read by docker-compose
DOCKER_COMPOSE_ENV = .env

DOCKER_USER ?= tqemci

export define DOCKER_COMPOSE_ENV_CONTENT
BASE_REGISTRY=${BASE_REGISTRY}
BASE_DOCKER_TAG=${BASE_DOCKER_TAG}
YOCTO_REGISTRY=${YOCTO_REGISTRY}
BUILD_TAG=${BUILD_TAG}
DOCKER_USER=${DOCKER_USER}
endef

DOCKER_COMPOSE := docker compose $(COMPOSE_FILE)

MAKE_DOCKER := $(MAKE) -f docker.mk

all: prepare
	${DOCKER_COMPOSE} build ${BUILD_ARGS} ${IMAGE}

prepare:
ifneq ("$(wildcard $(DOCKER_COMPOSE_ENV))","")
	$(info Using existing $(DOCKER_COMPOSE_ENV).)
else
	echo "$${DOCKER_COMPOSE_ENV_CONTENT}" > ${DOCKER_COMPOSE_ENV}
endif

push: prepare
ifeq ($(YOCTO_REGISTRY), $(LOCAL_YOCTO))
	$(error Prevent pushing to non-existing docker.io/$(LOCAL_YOCTO), exit.)
endif
	${DOCKER_COMPOSE} push ${IMAGE}

pull: prepare
	${DOCKER_COMPOSE} pull ${IMAGE}

clean:
	rm -f ${DOCKER_COMPOSE_ENV}
	docker system prune -f

release: all
	$(MAKE_DOCKER) push
	$(MAKE_DOCKER) clean

.PHONY: all prepare push pull clean release
