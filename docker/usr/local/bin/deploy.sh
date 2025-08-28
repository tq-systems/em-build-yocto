#!/bin/bash

set -e

DIR_SCRIPT=$(dirname "$0")
# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")
# shellcheck source=/dev/null
. "$DIR_SCRIPT/functions.sh"

MODE="$1"
ARG="$2"

case "$MODE" in
    artifact)
        copy_artifact "$ARG"
        ;;
    images)
        # skip first and second argument, so $@ contains only file links
        shift; shift
        copy_images "$ARG" "$@"
        ;;
    *)
        log_error "Unknown deployment mode: $MODE"
        ;;
esac
