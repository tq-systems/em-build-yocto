#!/bin/bash

set -e

DIR_SCRIPT=$(dirname "$0")
# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")
# shellcheck source=/dev/null
. "$DIR_SCRIPT/functions.sh"

TARGET=$1
TARGET_DIR=$2

ROOT_DIR=$(pwd)

# enable bitbake execution
cd_em_build
setup_build_environment

BUNDLE_SPEC_FILES=$(bitbake-getvar --value -r "$TARGET" EM_BUNDLE_SPEC)

ARTIFACTS_DIR=${ROOT_DIR}/${TARGET_DIR}
BUNDLE_SPECS_DIR=${ARTIFACTS_DIR}/bundle_specs

mkdir -p "$BUNDLE_SPECS_DIR" "$ARTIFACTS_DIR"

#copy spec files
for spec in $BUNDLE_SPEC_FILES; do
	find "${ROOT_DIR}/${DIR_YOCTO_WORK}" -type f -name "$spec" -exec cp {} "${BUNDLE_SPECS_DIR}/" \;
done

#copy bundles
find "${ROOT_DIR}/${DIR_YOCTO_DEPLOY}" -name "*.raucb" -exec cp {} "${ARTIFACTS_DIR}" \;
