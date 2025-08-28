#!/bin/bash

set -e

DIR_SCRIPT=$(dirname "$0")
# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")
# shellcheck source=/dev/null
. "$DIR_SCRIPT/functions.sh"

prepare_em_build
