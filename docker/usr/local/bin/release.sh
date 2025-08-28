#!/bin/bash

set -e

DIR_SCRIPT=$(dirname "$0")
# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")
# shellcheck source=/dev/null
. "$DIR_SCRIPT/functions.sh"

if [ $# -ne 1 ] && [ $# -ne 2 ]; then
    log_error "Usage: $SCRIPT_NAME <command> <optional: step>
commands:
    build         - run build steps only
    deploy        - run deploy steps only
    test [step]   - run single step only
"
fi

COMMAND="$1"
FUNCTION="$2" # used for the 'test' command only

[ -z "$PATH_BASE_DEPLOY" ] && log_error "Missing environment variable: PATH_BASE_DEPLOY"
[ -z "$REF_EM_BUILD" ]     && log_error "Missing environment variable: REF_EM_BUILD"

# Global variables
UNINATIVE="uninative-tarball"
CORE_IMAGE="em-image-core"

PATTERN_SOURCES_ARCHIVE="sources_${CORE_IMAGE}"
FILE_SOURCES_ARCHIVE="${PATTERN_SOURCES_ARCHIVE}_${REF_EM_BUILD}.tar.gz"

# The deploy script needs SUBDIR_BUILD_TYPE
export SUBDIR_BUILD_TYPE="$DIR_RELEASES"

PATH_DEPLOY_EMOS="$PATH_BASE_DEPLOY/$SUBDIR_BUILD_TYPE/emos/$SUBDIR_REF"

clean-deploy-dir() {
    log_info "Deleting $PATH_DEPLOY_EMOS..."
    rm -rfv "$PATH_DEPLOY_EMOS"
}

# Builds
build_sources_archive() {
    log_info "Fetch all sources for $UNINATIVE and $CORE_IMAGE"
    "$SCRIPT_BUILD" "$UNINATIVE" "$CORE_IMAGE" -R "${PATH_EM_YOCTO_CONF}/shallow-tarballs.conf" --runall=fetch

    # Remove old sources archives
    find . -maxdepth 1 -type f -name "*${PATTERN_SOURCES_ARCHIVE}*" -exec rm -f {} \;

    log_info "Create sources archive $FILE_ARCHIVE from $DIR_EM_BUILD"
    tar czf "$FILE_SOURCES_ARCHIVE" --numeric-owner --owner=0 --group=0 \
        "$DIR_YOCTO_DOWNLOADS" \
        --exclude="$DIR_YOCTO_BUILD" \
        "$DIR_EM_BUILD"
}

build_core_image_sbom() {
    log_info "Create sbom"
    "$SCRIPT_BUILD" sbom "$CORE_IMAGE"
}

build_core_image_cve() {
    log_info "Create cve-list"
    "$SCRIPT_BUILD" cve "$CORE_IMAGE"
}

build_core_image() {
    log_info "Build $CORE_IMAGE with release configuration"
    "$SCRIPT_BUILD" \
        -R "$PATH_EM_YOCTO_CONF/license-clearing-source-archives.conf" \
        -R "$PATH_EM_YOCTO_CONF/shallow-tarballs.conf" \
        -R "$PATH_EM_YOCTO_CONF/create-spdx.conf" \
        "$CORE_IMAGE"
}

build_toolchain() {
    log_info "Create toolchain"
    "$SCRIPT_BUILD" toolchain \
        -R "$PATH_EM_YOCTO_CONF/shallow-tarballs.conf"
}

build_fill_dlcache() {
    log_info "Fill download cache"
    "$SCRIPT_BUILD" fill-dl-cache
}

# Deployment
deploy_sources_archive() {
    copy_file "$FILE_SOURCES_ARCHIVE" \
        "$PATH_DEPLOY_EMOS/sources/build"
}

deploy_license_clearing_archives() {
    mkdir -p "$PATH_DEPLOY_EMOS/sources/license-clearing"
    find "$PATH_YOCTO_DEPLOY_SOURCES" -type f \
        -exec rsync -rl --ignore-existing {} "$PATH_DEPLOY_EMOS/sources/license-clearing" \;
}

deploy_manifest() {
    local machine dir_work_machine dir_target_rootfs path_deploy_manifest
    path_deploy_manifest="$PATH_DEPLOY_EMOS/sources/manifest"

    # shellcheck disable=SC2153
    for machine in $MACHINES; do
        copy_file_and_link "$PATH_YOCTO_DEPLOY_IMAGES/$machine/$CORE_IMAGE-$machine.manifest" \
            "$path_deploy_manifest"

        log_info "Copy packages data for $machine/$CORE_IMAGE"
        dir_work_machine="$(find "$DIR_YOCTO_WORK" -maxdepth 1 -type d -name "*$(echo "$machine" | tr '-' '_')*")"
        dir_target_rootfs="$(find "$dir_work_machine" -maxdepth 3 -type d -name "oe-rootfs-repo")"

        cat "${dir_target_rootfs}/Packages" > \
            "${path_deploy_manifest}/Packages_${machine}_${REF_EM_BUILD}.txt"
        cat "${dir_target_rootfs}/"*"/Packages" >> \
            "${path_deploy_manifest}/Packages_${machine}_${REF_EM_BUILD}.txt"
    done
}

deploy_archives_mirror() {
    [ -z "$MIRROR_URI" ] && log_error "Missing environment variable: MIRROR_URI"
    [ -z "$MIRROR_PATH" ] && log_error "Missing environment variable: MIRROR_PATH"

    log_info "Deploy archives including shallow tarballs of target $CORE_IMAGE to $MIRROR_URI:$MIRROR_PATH"
    rsync -za --copy-links --exclude '*.done' --exclude 'apps*' --exclude 'git2*' "$PATH_YOCTO_DOWNLOADS"/* "$MIRROR_URI:$MIRROR_PATH"
}

deploy_core() {
    copy_artifact "$CORE_IMAGE"
    copy_artifact toolchain
}

deploy_core_image_sbom() {
    copy_artifact sbom
}

deploy_core_image_cve() {
    for machine in $MACHINES; do
        copy_file_and_link "$PATH_YOCTO_DEPLOY_IMAGES/$machine/$CORE_IMAGE-$machine.cve.json" \
            "$PATH_DEPLOY_EMOS/sources/cve-list/"
    done
}

deploy_core_image_spdx() {
    for machine in $MACHINES; do
        copy_file_and_link "$PATH_YOCTO_DEPLOY_IMAGES/$machine/$CORE_IMAGE-$machine.spdx.tar.zst" \
            "$PATH_DEPLOY_EMOS/sources/spdx/"
    done
}

# QA
check_mirror() {
    # Only check the download of the archives (incl. shallow tarballs). The following build uses
    # a different download directory: DL_DIR = "${TOPDIR}/downloads_check"
    log_info "Test download of mirrored archives (incl. shallow tarballs)"
    "$SCRIPT_BUILD" -R "$PATH_EM_YOCTO_CONF/test-mirror.conf" "$CORE_IMAGE" --force --runall=fetch
}

# MAIN
case "$COMMAND" in
fetch)
    build_sources_archive
    ;;
build)
    build_core_image
    build_core_image_sbom
    build_core_image_cve
    build_toolchain
    build_fill_dlcache
    ;;
deploy)
    deploy_archives_mirror
    deploy_sources_archive
    deploy_license_clearing_archives
    deploy_manifest
    deploy_core
    deploy_core_image_sbom
    deploy_core_image_spdx
    deploy_core_image_cve
    check_mirror
    ;;
clean-deploy-dir)
    clean-deploy-dir
    ;;
test)
    ${FUNCTION}
    ;;
*)
    log_error "Unknown command: $COMMAND"
esac

log_info "$COMMAND command finished successfully"
