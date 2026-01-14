#!/bin/bash

set -e

DIR_SCRIPT=$(dirname "$0")
# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")
# shellcheck source=/dev/null
. "$DIR_SCRIPT/functions.sh"

if [ $# -ne 1 ] && [ $# -ne 2 ]; then
    tqem_log_error_and_exit "Usage: $SCRIPT_NAME <command> <optional: step>
commands:
    build         - run build steps only
    collect       - run collect steps only
    test [step]   - run single step only
"
fi

COMMAND="$1"
FUNCTION="${2:-}" # used for the 'test' command only

[ -z "$TQEM_ARTIFACTS_PATH" ] && tqem_log_error_and_exit "Missing environment variable: TQEM_ARTIFACTS_PATH"
[ -z "$TQEM_EM_BUILD_REF" ]     && tqem_log_error_and_exit "Missing environment variable: TQEM_EM_BUILD_REF"

# Global variables
UNINATIVE="uninative-tarball"
CORE_IMAGE="em-image-core"

PATTERN_SOURCES_ARCHIVE="sources_${CORE_IMAGE}"
FILE_SOURCES_ARCHIVE="${PATTERN_SOURCES_ARCHIVE}_${TQEM_EM_BUILD_REF}.tar.gz"

# The collect script needs TQEM_BUILD_TYPE_SUBDIR
export TQEM_BUILD_TYPE_SUBDIR="$TQEM_RELEASES_DIR"

TQEM_COLLECT_PATH="$TQEM_ARTIFACTS_PATH/$TQEM_BUILD_TYPE_SUBDIR/emos/$TQEM_EM_BUILD_REF"

clean-collect-dir() {
    tqem_log_info "Deleting $TQEM_COLLECT_PATH..."
    rm -rfv "$TQEM_COLLECT_PATH"
}

# Builds
build_sources_archive() {
    tqem_log_info "Fetch all sources for $UNINATIVE and $CORE_IMAGE"
    "$BUILD_SCRIPT" "$UNINATIVE" "$CORE_IMAGE" -R "${TQEM_ADD_CONF_PATH}/shallow-tarballs.conf" --runall=fetch

    # Remove old sources archives
    find . -maxdepth 1 -type f -name "*${PATTERN_SOURCES_ARCHIVE}*" -exec rm -f {} \;

    tqem_log_info "Create sources archive $FILE_SOURCES_ARCHIVE from $TQEM_EM_BUILD_DIR"
    # Need two consecutive tar calls in order to include a subdir of
    # an excluded directory (build/downloads)
    TMP_ARCHIVE="${FILE_SOURCES_ARCHIVE%.*}"

    # archive em-build without build/
    tar hcf "$TMP_ARCHIVE" --numeric-owner --owner=0 --group=0 \
        --exclude-vcs \
        --exclude="$TQEM_YOCTO_BUILD_DIR" \
        --exclude="*.done" \
        --exclude="apps_*" \
        "$TQEM_EM_BUILD_DIR"

    # archive build/downloads without build/downloads/git2
    tar hrf "$TMP_ARCHIVE" --numeric-owner --owner=0 --group=0 \
        --exclude-vcs \
        --exclude "$TQEM_YOCTO_DOWNLOADS_DIR/git2" \
        --exclude="*.done" \
        --exclude="apps_*" \
        "$TQEM_YOCTO_DOWNLOADS_DIR"

    # create final FILE_SOURCES_ARCHIVE
    gzip "$TMP_ARCHIVE"
}

build_core_image_sbom() {
    tqem_log_info "Create sbom"
    "$BUILD_SCRIPT" sbom "$CORE_IMAGE"
}

build_core_image_cve() {
    tqem_log_info "Create cve-list"
    "$BUILD_SCRIPT" cve "$CORE_IMAGE"
}

build_core_image() {
    tqem_log_info "Build $CORE_IMAGE with release configuration"
    "$BUILD_SCRIPT" \
        -R "$TQEM_ADD_CONF_PATH/license-clearing.conf" \
        -R "$TQEM_ADD_CONF_PATH/shallow-tarballs.conf" \
        -R "$TQEM_ADD_CONF_PATH/create-spdx.conf" \
        "$CORE_IMAGE"
}

build_toolchain() {
    tqem_log_info "Create toolchain"
    "$BUILD_SCRIPT" toolchain \
        -R "$TQEM_ADD_CONF_PATH/shallow-tarballs.conf"
}

build_fill_dlcache() {
    tqem_log_info "Fill download cache"
    "$BUILD_SCRIPT" fill-dl-cache
}

# Collecting
collect_sources_archive() {
    mkdir -p "$TQEM_COLLECT_PATH/sources/build"
    cp "$FILE_SOURCES_ARCHIVE" \
        "$TQEM_COLLECT_PATH/sources/build"
}

collect_license_clearing_archives() {
    mkdir -p "$TQEM_COLLECT_PATH/sources/license-clearing"
    find "$TQEM_YOCTO_DEPLOY_SOURCES_PATH" -type f \
        -exec rsync -rl --ignore-existing {} "$TQEM_COLLECT_PATH/sources/license-clearing" \;
}

collect_manifest() {
    local machine dir_work_machine dir_target_rootfs path_collect_manifest
    path_collect_manifest="$TQEM_COLLECT_PATH/sources/manifest"

    # shellcheck disable=SC2153
    for machine in $TQEM_MACHINES; do
        tqem-copy.sh "$TQEM_YOCTO_DEPLOY_IMAGES_PATH/$machine/$CORE_IMAGE-$machine.manifest" \
            "$path_collect_manifest"

        tqem_log_info "Copy packages data for $machine/$CORE_IMAGE"
        dir_work_machine="$(find "$TQEM_YOCTO_WORK_DIR" -maxdepth 1 -type d -name "*$(echo "$machine" | tr '-' '_')*")"
        dir_target_rootfs="$(find "$dir_work_machine" -maxdepth 3 -type d -name "oe-rootfs-repo")"

        cat "${dir_target_rootfs}/Packages" > \
            "${path_collect_manifest}/Packages_${machine}_${TQEM_EM_BUILD_REF}.txt"
        cat "${dir_target_rootfs}/"*"/Packages" >> \
            "${path_collect_manifest}/Packages_${machine}_${TQEM_EM_BUILD_REF}.txt"
    done

    # Copy combined license manifest if it exists
    local combined_license_manifest="$TQEM_YOCTO_TMP_DIR/collect/licenses/em-combined-licenses/license.manifest"
    if [ -f "$combined_license_manifest" ]; then
        tqem_log_info "Copy combined license manifest"
        mkdir -p "$path_collect_manifest"
        cp "$combined_license_manifest" "$path_collect_manifest/$CORE_IMAGE-combined.license.manifest"
    fi
}

collect_archives_mirror() {
    [ -z "$MIRROR_URI" ] && tqem_log_error_and_exit "Missing environment variable: MIRROR_URI"
    [ -z "$MIRROR_PATH" ] && tqem_log_error_and_exit "Missing environment variable: MIRROR_PATH"

    tqem_log_info "Collect archives including shallow tarballs of target $CORE_IMAGE to $MIRROR_URI:$MIRROR_PATH"
    rsync -za --copy-links --exclude '*.done' --exclude 'apps*' --exclude 'git2*' "$TQEM_YOCTO_DOWNLOADS_PATH"/* "$MIRROR_URI:$MIRROR_PATH"
}

archive_bootloaders() {
    local machine="$1"
    local core_image_link core_image_file suffix

    rm -f "${TQEM_YOCTO_DEPLOY_IMAGES_PATH}/${machine}"/em-image-core-*.bootloader.tar

    core_image_link="${TQEM_YOCTO_DEPLOY_IMAGES_PATH}/${machine}/em-image-core-$machine.tar"
    core_image_file="$(readlink -f "$core_image_link")"
    core_image_file="$(basename "${core_image_file}" .rootfs.tar)"
    suffix="${core_image_file##em-image-core-}"

    # Use subshell to match $BOOTLOADERS[...] patterns relative to the right directory
    (
        # shellcheck disable=SC2086
        cd "${TQEM_YOCTO_DEPLOY_IMAGES_PATH}/${machine}" && \
        tar --owner=0 --group=0 --numeric-owner --sort=name --mtime=@0 \
            -chf "em-image-core-${suffix}.bootloader.tar" ${BOOTLOADERS[$machine]}
    )
    ln -sf "em-image-core-${suffix}.bootloader.tar" "${TQEM_YOCTO_DEPLOY_IMAGES_PATH}/${machine}/em-image-core-${machine}.bootloader.tar"
}

collect_core() {
    for machine in $TQEM_MACHINES; do
        architecture="aarch64"

        # core-image
        tqem-copy.sh "$TQEM_YOCTO_DEPLOY_IMAGES_PATH/$machine/em-image-core-$machine.tar" "$TQEM_COLLECT_PATH/core-image/$machine" --links --overwrite

        # bootloader
        archive_bootloaders "$machine"
        tqem-copy.sh "$TQEM_YOCTO_DEPLOY_IMAGES_PATH/$machine/em-image-core-$machine.bootloader.tar" "$TQEM_COLLECT_PATH/core-image/$machine"  --links --overwrite

        # toolchain
        tqem-copy.sh "$TQEM_YOCTO_DEPLOY_SDK_PATH/emos-x86_64-$architecture-toolchain.sh" "$TQEM_COLLECT_PATH/toolchain/$architecture" --links --overwrite
    done
}

collect_core_image_sbom() {
    for machine in $TQEM_MACHINES; do
        if [ "$machine" = "em-aarch64" ]; then
            path_source="$TQEM_YOCTO_DEPLOY_PATH/cyclonedx-export/bom_${machine}_merged.json"
        else
            path_source="$TQEM_YOCTO_DEPLOY_PATH/cyclonedx-export/bom_${machine}.json"
        fi

        tqem-copy.sh "$path_source" "$TQEM_COLLECT_PATH/core-image/$machine"
    done
}

collect_core_image_cve() {
    for machine in $TQEM_MACHINES; do
        tqem-copy.sh "$TQEM_YOCTO_DEPLOY_IMAGES_PATH/$machine/$CORE_IMAGE-$machine.cve.json" "$TQEM_COLLECT_PATH/sources/cve-list/"
    done
}

collect_core_image_spdx() {
    for machine in $TQEM_MACHINES; do
        tqem-copy.sh  "$TQEM_YOCTO_DEPLOY_IMAGES_PATH/$machine/$CORE_IMAGE-$machine.spdx.tar.zst" "$TQEM_COLLECT_PATH/sources/spdx/"
    done
}

# QA
check_mirror() {
    # Only check the download of the archives (incl. shallow tarballs). The following build uses
    # a different download directory: DL_DIR = "${TOPDIR}/downloads_check"
    tqem_log_info "Test download of mirrored archives (incl. shallow tarballs)"
    "$BUILD_SCRIPT" -R "$TQEM_ADD_CONF_PATH/test-mirror.conf" "$CORE_IMAGE" --force --runall=fetch
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
    ;;
collect)
    collect_sources_archive
    collect_license_clearing_archives
    collect_manifest
    collect_core
    collect_core_image_sbom
    collect_core_image_spdx
    collect_core_image_cve
    ;;
mirror)
    build_fill_dlcache
    collect_archives_mirror
    check_mirror
    ;;
clean-collect-dir)
    clean-collect-dir
    ;;
test)
    ${FUNCTION}
    ;;
*)
    tqem_log_error_and_exit "Unknown command: $COMMAND"
esac

tqem_log_info "$COMMAND command finished successfully"
