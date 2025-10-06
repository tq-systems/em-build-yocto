#!/bin/bash

# source shell library for logging functions
# shellcheck source=/dev/null
. /usr/local/lib/tqem/shell/log.sh

LOCAL_LAYER_DIR="local"
LOCAL_LAYER_CONF="$LOCAL_LAYER_DIR/em-layers.conf"

declare -A BOOTLOADERS
BOOTLOADERS[em310]='u-boot.sb-em310'
BOOTLOADERS[em-aarch64]='bootloader-*.bin'

# Functions

cd_em_build() {
	cd "$TQEM_EM_BUILD_DIR" || tqem_log_error_and_exit "Cannot change directory to: $TQEM_EM_BUILD_DIR"
}

setup_em_build() {
	git init
	git checkout --detach 2>/dev/null || git checkout -B _
	git fetch -pf "$TQEM_EM_BUILD_GIT_REPO" 'refs/*:refs/*'
	git checkout "$TQEM_EM_BUILD_REF"
}

handle_local_layer_conf() {
	# Copy the static layer configuration file if it exists
	if [ -e "$LOCAL_LAYER_CONF_PATH" ]; then
		mkdir -p "$LOCAL_LAYER_DIR"
		cp -f "$LOCAL_LAYER_CONF_PATH" "$LOCAL_LAYER_CONF"
	fi

	# Create a variable layer configuration, it can override the static one
	if [ -n "$OVERRIDE_LOCAL_CONF" ]; then
		mkdir -p "$LOCAL_LAYER_DIR"
		echo "$OVERRIDE_LOCAL_CONF" > "$LOCAL_LAYER_CONF"
	fi

	# Append a variable layer configuration to the static one
	if [ -n "$ADD_LOCAL_CONF" ] && [ -e "$LOCAL_LAYER_CONF_PATH" ]; then
		echo "$ADD_LOCAL_CONF" >> "$LOCAL_LAYER_CONF"
	fi

	# Clean up old local layer configurations
	if [ -e "$LOCAL_LAYER_CONF" ] && \
		[ ! -e "$LOCAL_LAYER_CONF_PATH" ] && [ -z "$OVERRIDE_LOCAL_CONF" ]; then
		rm -rf "$LOCAL_LAYER_DIR"
	fi

	if [ -e "$LOCAL_LAYER_CONF" ]; then
		tqem_log_info "Found local layer configuration:"
		cat "$LOCAL_LAYER_CONF"
	else
		tqem_log_info "No local layer configuration found"
	fi
}

setup_local_yocto_conf() {
	if [ -e "$PATH_LOCAL_YOCTO_CONF/site.conf" ]; then
		tqem_log_info "Found local site.conf:"
		ln -sf "$PATH_LOCAL_YOCTO_CONF/site.conf" "conf/site.conf"
	else
		tqem_log_info "No local site.conf found"
	fi
}

update_em_layers() {
	./em-update
}

# pull em-build and layers and prepare build
prepare_em_build() {
	mkdir -p "$TQEM_EM_BUILD_DIR"
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

add_string() {
	local string="$1"

	if ! grep -Fxq "$string" "$TQEM_YOCTO_LOCAL_CONF"; then
		echo "$string" >> "$TQEM_YOCTO_LOCAL_CONF"
		tqem_log_info "Added $string to local.conf"
	fi
}

remove_string() {
	local string="$1"

	if grep -Fxq "$string" "$TQEM_YOCTO_LOCAL_CONF"; then
		sed -i "/^${string}/d" "$TQEM_YOCTO_LOCAL_CONF"
		tqem_log_info "Removed $string from local.conf"
	fi
}

# The 'em-aarch' machine builds several machine variants for the aarch64 architecture. Build time
# can be saved by deactivating the unused variants. As the 'EM_AARCH64_em-cb30' string is not
# compatible with the bash, it cannot be deactivated by using the BB_ENV_PASSTHROUGH_ADDITIONS.
# As a workaround we adjust the local.conf reading the TQEM_EM_AARCH64_MACHINE variable.
adjust_local_conf_machine() {
	local machine="$1"

	local deactivate_em_cb30="EM_AARCH64_em-cb30 = \"0\""
	local deactivate_em4xx="EM_AARCH64_em4xx = \"0\""

	[ -f "$TQEM_YOCTO_LOCAL_CONF" ] || tqem_log_error_and_exit "Cannot find local.conf"
	case $TQEM_EM_AARCH64_MACHINE in
	em4xx)
		add_string "$deactivate_em_cb30"
		remove_string "$deactivate_em4xx"
		;;
	em-cb30)
		add_string "$deactivate_em4xx"
		remove_string "$deactivate_em_cb30"
		;;
	*)
		remove_string "$deactivate_em4xx"
		remove_string "$deactivate_em_cb30"
		;;
	esac
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
