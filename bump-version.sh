#!/bin/bash
# Copyright (c) 2026 TQ-Systems GmbH

set -e

VERSION="$1"
GITLAB_CI_FILE=".gitlab-ci.yml"

set_base_docker_tag() {
	local docker_tag="v${1}"
	sed -i "s/^\(  YOCTO_DOCKER_TAG: '\)[^']*'/\1${docker_tag}'/" "$GITLAB_CI_FILE"
}

set_base_docker_tag "$VERSION"
git add "$GITLAB_CI_FILE"
