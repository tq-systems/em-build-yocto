#!/bin/bash

DIR_LOCAL="local"
FILE_LOCAL_CONF="$DIR_LOCAL/em-layers.conf"

# Architecture mapping:
# We only need one toolchain per architecture, and duplicating toolchains can
# lead to deployment errors. Therefore we iterate over a reduced list of
# machines in which each architecture occurs only once.
# Here is a mapping of machines on arch:
# em310                 = armv5e
# em-aarch64/imx8mn-egw = aarch64
declare -A TOOLCHAINS
TOOLCHAINS[em310]=armv5e
TOOLCHAINS[em-aarch64]=aarch64
# shellcheck disable=SC2034
TOOLCHAINS[imx8mn-egw]=

declare -A BOOTLOADERS
BOOTLOADERS[em310]='u-boot.sb-em310'
BOOTLOADERS[em-aarch64]='bootloader-*.bin'
BOOTLOADERS[imx8mn-egw]='flash.bin-512m'

# Functions
log_info() {
    local message="$1"
    echo "[$SCRIPT_NAME]: $message"
}

log_error() {
    local message="$1"
    echo >&2 "[$SCRIPT_NAME]: $message"
    exit 1
}

cd_em_build() {
    cd "$DIR_EM_BUILD" || log_error "Cannot change directory to: $DIR_EM_BUILD"
}

setup_em_build() {
    git init
    git checkout --detach 2>/dev/null || git checkout -B _
    git fetch -pf "$GIT_EM_BUILD" 'refs/*:refs/*'
    git checkout "$REF_EM_BUILD"
}

handle_local_layer_conf() {
    # Copy the static layer configuration file if it exists
    if [ -e "$PATH_LOCAL_CONF" ]; then
        mkdir -p "$DIR_LOCAL"
        cp -f "$PATH_LOCAL_CONF" "$FILE_LOCAL_CONF"
    fi

    # Create a variable layer configuration, it can override the static one
    if [ -n "$OVERRIDE_LOCAL_CONF" ]; then
        mkdir -p "$DIR_LOCAL"
        echo "$OVERRIDE_LOCAL_CONF" > "$FILE_LOCAL_CONF"
    fi

    # Append a variable layer configuration to the static one
    if [ -n "$ADD_LOCAL_CONF" ] && [ -e "$PATH_LOCAL_CONF" ]; then
        echo "$ADD_LOCAL_CONF" >> "$FILE_LOCAL_CONF"
    fi

    # Clean up old local layer configurations
    if [ -e "$FILE_LOCAL_CONF" ] && \
        [ ! -e "$PATH_LOCAL_CONF" ] && [ -z "$OVERRIDE_LOCAL_CONF" ]; then
        rm -rf "$DIR_LOCAL"
    fi

    if [ -e "$FILE_LOCAL_CONF" ]; then
        log_info "Found local layer configuration:"
        cat "$FILE_LOCAL_CONF"
    else
        log_info "No local layer configuration found"
    fi
}

setup_local_yocto_conf() {
    if [ -e "$PATH_LOCAL_YOCTO_CONF/site.conf" ]; then
        log_info "Found local Yocto configuration:"
        ln -sf "$PATH_LOCAL_YOCTO_CONF/site.conf" "conf/site.conf"
    else
        log_info "No local Yocto configuration found"
    fi
}

update_em_layers() {
    ./em-update
}

# pull em-build and layers and prepare build
prepare_em_build() {
    mkdir -p "$DIR_EM_BUILD"
    cd_em_build
    setup_em_build
    handle_local_layer_conf
    update_em_layers
}

# setup_build_environment expects an existing em-build directory
setup_build_environment() {
    # shellcheck source=/dev/null
    . ./em-build-env
}

get_device_type() {
    local machine="$1"
    local hardware_type

    case "$machine" in
        em310)
            hardware_type="hw0100"
            ;;
        em-aarch64)
            hardware_type="hw02xx"
            ;;
        imx8mn-egw)
            hardware_type="$machine"
            ;;
        *)
            log_error "Unknown machine: $machine"
        ;;
    esac

    echo "$hardware_type"
}

archive_bootloaders() {
    local machine="$1"
    local core_image_link core_image_file suffix

    rm -f "${PATH_YOCTO_DEPLOY_IMAGES}/${machine}"/em-image-core-*.bootloader.tar

    core_image_link="${PATH_YOCTO_DEPLOY_IMAGES}/${machine}/em-image-core-$machine.tar"
    core_image_file="$(readlink -f "$core_image_link")"
    core_image_file="$(basename "${core_image_file}" .rootfs.tar)"
    suffix="${core_image_file##em-image-core-}"

    # Use subshell to match $BOOTLOADERS[...] patterns relative to the right directory
    (
        cd "${PATH_YOCTO_DEPLOY_IMAGES}/${machine}" && \
        tar --owner=0 --group=0 --numeric-owner --sort=name --mtime=@0 \
            -chf "em-image-core-${suffix}.bootloader.tar" ${BOOTLOADERS[$machine]}
    )
    ln -sf "em-image-core-${suffix}.bootloader.tar" "${PATH_YOCTO_DEPLOY_IMAGES}/${machine}/em-image-core-${machine}.bootloader.tar"
}

# Copy files and directories inside source directory to destination directory
copy_directory_content() {
    local path_source_dir="$1"
    local path_deploy_dir="$2"

    [ -d "$path_source_dir" ] || log_error "Cannot find directory: $path_source_dir"

    mkdir -p "$path_deploy_dir"
    log_info "Copy the content of $path_source_dir to $path_deploy_dir"
    rsync -rl --ignore-existing "$path_source_dir/" "$path_deploy_dir"
}

copy_file_prepare() {
    local path_source_file="$1"
    local path_deploy_dir="$2"

    [ -r "$path_source_file" ] || log_error "Cannot find file: $path_source_file"

    local path_deploy_file
    path_deploy_file="$path_deploy_dir/$(basename "$path_source_file")"

    if [ -e "$path_deploy_file" ] && [ "$OVERRIDE_SNAPSHOTS" != "true" ]; then
        log_error "File already exists: $path_deploy_file"
    fi

    mkdir -p "$path_deploy_dir"
}

copy_file_and_link() {
    local path_source_link="$1"
    local path_deploy_dir="$2"

    [ -L "$path_source_link" ] || log_error "No symbolic link: $path_source_link"

    local path_source_file
    path_source_file="$(readlink -f "$path_source_link")"
    copy_file_prepare "$path_source_file" "$path_deploy_dir"

    # TODO: Reimplement the simple commands again, if we can use symlinks:
    # log_info "Copy the link $path_source_link and its file to $path_deploy_dir"
    # rsync -rl "$path_source_file" "$path_source_link" "$path_deploy_dir"

    # Workaround for windows filesystem which cannot handle symbolic links
    if [ "$SUBDIR_BUILD_TYPE" = "snapshots" ]; then
        log_info "Copy $path_source_file and $path_source_link to $path_deploy_dir"
        rsync -rL "$path_source_file" "$path_source_link" "$path_deploy_dir"
    else
        log_info "Copy $path_source_file to $path_deploy_dir"
        rsync -r "$path_source_file" "$path_deploy_dir"
    fi
}

copy_file() {
    local path_source_file="$1"
    local path_deploy_dir="$2"

    copy_file_prepare "$path_source_file" "$path_deploy_dir"

    log_info "Copy $path_source_file to $path_deploy_dir"
    rsync -rl "$path_source_file" "$path_deploy_dir"
}

subdir_machine() {
    local machine="$1"

    if [ -n "$SUBDIR_MACHINE_OVERRIDE" ]; then
        echo "$SUBDIR_MACHINE_OVERRIDE"
    else
        echo "$machine"
    fi
}

copy_artifact() {
    local artifact="$1"
    local machine subdir architecture path_source_link path_deploy_dir device_type

    # shellcheck disable=SC2153
    for machine in $MACHINES; do
        architecture="${TOOLCHAINS[$machine]}"
        subdir="$(subdir_machine "$machine")"

        case "$artifact" in
        em-image-core)
            path_source_link="$PATH_YOCTO_DEPLOY_IMAGES/$machine/$artifact-$machine.tar"
            path_deploy_dir="$PATH_BASE_DEPLOY/$SUBDIR_BUILD_TYPE/emos/$SUBDIR_REF/core-image/$subdir"
            copy_file_and_link "$path_source_link" "$path_deploy_dir"

            archive_bootloaders "$machine"
            path_source_link="$PATH_YOCTO_DEPLOY_IMAGES/$machine/$artifact-$machine.bootloader.tar"
            copy_file_and_link "$path_source_link" "$path_deploy_dir"
            ;;
        toolchain)
            [ -n "$architecture" ] || continue

            path_source_link="$PATH_YOCTO_DEPLOY_SDK/emos-x86_64-$architecture-toolchain.sh"
            path_deploy_dir="$PATH_BASE_DEPLOY/$SUBDIR_BUILD_TYPE/emos/$SUBDIR_REF/toolchain/$architecture"
            copy_file_and_link "$path_source_link" "$path_deploy_dir"
            ;;
        em-bundle-*)
            bundle_name=${artifact#em-bundle-}
            device_type="$(get_device_type "$machine")"
            path_source_link="$PATH_YOCTO_DEPLOY_IMAGES/$machine/$bundle_name-$device_type.raucb"
            path_deploy_dir="$PATH_BASE_DEPLOY/$SUBDIR_BUILD_TYPE/emos/$SUBDIR_REF/$bundle_name-bundle/$subdir"
            copy_file_and_link "$path_source_link" "$path_deploy_dir"
            ;;
        sbom)
            if [ "$machine" = "em-aarch64" ]; then
                path_source_link="$PATH_YOCTO_DEPLOY/cyclonedx-export/bom_${machine}_merged.json"
            else
                path_source_link="$PATH_YOCTO_DEPLOY/cyclonedx-export/bom_${machine}.json"
            fi

            path_deploy_dir="$PATH_BASE_DEPLOY/$SUBDIR_BUILD_TYPE/emos/$SUBDIR_REF/core-image/$subdir"
            copy_file "$path_source_link" "$path_deploy_dir"
            ;;
        *)
            log_error "Unknown deployment: $artifact"
        esac

    done
}

copy_images() {
    local machine="$1"
    local subdir path_deploy_dir path_source_link

    subdir="$(subdir_machine "$machine")"

    [ -z "$SUBDIR_DEPLOY" ] && log_error "Missing environment variable: SUBDIR_DEPLOY"
    path_deploy_dir="$PATH_BASE_DEPLOY/$SUBDIR_BUILD_TYPE/emos/$SUBDIR_REF/$SUBDIR_DEPLOY/$subdir"

    shift # skip first argument, so $@ contains only file links
    for link in "$@"; do
        path_source_link="$PATH_YOCTO_DEPLOY_IMAGES/$machine/$link"
        copy_file_and_link "$path_source_link" "$path_deploy_dir"
    done
}

sync_downloads_to_dlcache () {
    local dl_dir="$1"
    local source_mirror_url="$2"

    [ -n "$dl_dir" ] || log_error "Missing DL_DIR"
    [ -n "$source_mirror_url" ] || log_error "Missing SOURCE_MIRROR_URL"
    [ ! -d "${source_mirror_url}" ] && log_error "Cannot find source mirror: $source_mirror_url"

    log_info "Copy tarballs from $dl_dir to $source_mirror_url ..."
    # search for newly downloaded files, links point to mounted
    # SOURCE_MIRROR_URL. *.done files are only state info
    find "${dl_dir}" -maxdepth 1 -type f -readable -not -name "*.done" -print0 | \
        xargs --null --no-run-if-empty cp --no-clobber -v --target-directory="${source_mirror_url}/"

    # uninative normally consists of one file, so the loop should
    # be no problem here
    cd "${dl_dir}" || return 0
    files=$(find uninative -maxdepth 2 -type f -readable -not -name "*.done" || true)
    for f in ${files}; do
        dir=$(dirname "${f}")
        mkdir -p "${source_mirror_url}/${dir}"
        cp --no-clobber -v "${f}" "${source_mirror_url}/${dir}"
    done
}
