# Default string, if no docker registry is defined
LOCAL_YOCTO = local/em/yocto

# Default strings for dependent base image
BASE_REGISTRY_IMAGE ?= local/em/base
BASE_DOCKER_TAG ?= latest

COMPOSE_FILE ?= -f docker-compose.yml
IMAGE ?= build

# Support gitlab environment variables if existent
ifdef CI_REGISTRY_IMAGE
  YOCTO_REGISTRY_IMAGE = ${CI_REGISTRY_IMAGE}
endif
YOCTO_REGISTRY_IMAGE ?= ${LOCAL_YOCTO}

ifdef CI_COMMIT_TAG
  YOCTO_DOCKER_TAG = ${CI_COMMIT_TAG}
endif
YOCTO_DOCKER_TAG ?= latest

# Additional docker-compose build options may be set (e.g. --no-cache)
BUILD_ARGS ?=

# .env file is read by docker-compose
DOCKER_COMPOSE_ENV = .env

export define DOCKER_COMPOSE_ENV_CONTENT
BASE_REGISTRY_IMAGE=${BASE_REGISTRY_IMAGE}
BASE_DOCKER_TAG=${BASE_DOCKER_TAG}
YOCTO_REGISTRY_IMAGE=${YOCTO_REGISTRY_IMAGE}
YOCTO_DOCKER_TAG=${YOCTO_DOCKER_TAG}
endef

prepare:
ifneq ("$(wildcard $(DOCKER_COMPOSE_ENV))","")
	$(info Using existing $(DOCKER_COMPOSE_ENV).)
else
	echo "$${DOCKER_COMPOSE_ENV_CONTENT}" > ${DOCKER_COMPOSE_ENV}
endif

all: prepare
	docker-compose ${COMPOSE_FILE} build ${BUILD_ARGS} ${IMAGE}

push: prepare
ifeq ($(YOCTO_REGISTRY_IMAGE), $(LOCAL_YOCTO))
	$(error Prevent pushing to non-existing docker.io/$(LOCAL_YOCTO), exit.)
endif
	docker-compose ${COMPOSE_FILE} push ${IMAGE}

pull: prepare
	docker-compose ${COMPOSE_FILE} pull ${IMAGE}

clean:
	rm -f ${DOCKER_COMPOSE_ENV}
	docker system prune -f

release: all push clean

.NOTPARALLEL: release

.PHONY: all prepare  push pull clean release
