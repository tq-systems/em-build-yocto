#!/bin/bash

set -e

DIR_SCRIPT=$(dirname "$0")
# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")
# shellcheck source=/dev/null
. "$DIR_SCRIPT/functions.sh"

[ $# -lt 1 ] && tqem_log_error_and_exit "Missing target(s)"

usage() {
	echo "NAME

       $SCRIPT_NAME - build a yocto recipe

SYNOPSIS

       $SCRIPT_NAME [RECIPE(s) or KEYWORD]

DESCRIPTION

       The script builds each passed Yocto recipe, provided it is included in the configured Yocto
       layers. There are special keywords for the following builds:

       core-image
              Build the core image with the Energy Manager operating system

       toolchain
              Build the cross-compiler toolchain script
"
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	usage; exit 0
fi

LOG_MACHINES="$TQEM_MACHINES"
if [ -n "$TQEM_EM_AARCH64_MACHINE" ]; then
	LOG_MACHINES="$TQEM_MACHINES ($TQEM_EM_AARCH64_MACHINE)"
fi

# shellcheck disable=SC2153
tqem_log_info "Build with the following parameters:
build targets:      $*
machines:           $LOG_MACHINES
em-build reference: $TQEM_EM_BUILD_REF
"

# An EULA need to be accepted for the em-aarch64 build
# shellcheck disable=SC2034
BB_ENV_PASSTHROUGH_ADDITIONS='ACCEPT_FSL_EULA EM_AARCH64_em-cb30'
export ACCEPT_FSL_EULA='1'

cd_em_build
setup_build_environment
setup_local_yocto_conf
adjust_local_conf_machine "$TQEM_EM_AARCH64_MACHINE"

TARGET="$1"

TQEM_COLLECT_PATH="$TQEM_ARTIFACTS_PATH/$TQEM_BUILD_TYPE_SUBDIR/emos/$TQEM_EM_BUILD_REF"

case $TARGET in
core-image)
	for MACHINE in $TQEM_MACHINES; do
		MACHINE="$MACHINE" bitbake -R "${TQEM_ADD_CONF_PATH}/shallow-tarballs.conf" \
			em-image-core

		CORE_IMAGE_PATH="$(find "$TQEM_YOCTO_DEPLOY_IMAGES_PATH/$MACHINE" -type l -name "*em-image-core-${MACHINE}.tar")"
		CORE_IMAGE_DEPLOY_PATH="$TQEM_COLLECT_PATH/core-image/$MACHINE"
		tqem-copy.sh "$CORE_IMAGE_PATH" "$CORE_IMAGE_DEPLOY_PATH" --links --overwrite

		archive_bootloaders "$MACHINE"
		tqem-copy.sh "$TQEM_YOCTO_DEPLOY_IMAGES_PATH/$MACHINE/em-image-core-${MACHINE}.bootloader.tar" \
			"$CORE_IMAGE_DEPLOY_PATH" --links --overwrite
	done
	;;
toolchain)
	for MACHINE in $TQEM_MACHINES; do
		MACHINE="$MACHINE" bitbake -R "${TQEM_ADD_CONF_PATH}/shallow-tarballs.conf" \
			em-image-core -c populate_sdk

		# Find and link the toolchain to simplify its deployment
		ARCHITECTURE="$(tqem-device.sh arch "$MACHINE")"
		TOOLCHAIN_PATTERN="emos-x86_64-${ARCHITECTURE}-toolchain"
		TOOLCHAIN_PATH=$(find "${TQEM_YOCTO_DEPLOY_SDK_PATH}" -type f -name "*${TOOLCHAIN_PATTERN}*.sh")
		TOOLCHAIN_FILE="$(basename "$TOOLCHAIN_PATH")"
		ln -sf "$TOOLCHAIN_FILE" "${TQEM_YOCTO_DEPLOY_SDK_PATH}/${TOOLCHAIN_PATTERN}.sh"

		tqem-copy.sh "${TQEM_YOCTO_DEPLOY_SDK_PATH}/${TOOLCHAIN_PATTERN}.sh" \
			"$TQEM_COLLECT_PATH/toolchain/$ARCHITECTURE" --links --overwrite
	done
	;;
cve)
	shift
	for MACHINE in $TQEM_MACHINES; do
		MACHINE="$MACHINE" bitbake \
		-R "$TQEM_ADD_CONF_PATH/check-vulnerabilities.conf" "$@"

		BBMULTICONFIG=$(MACHINE=$MACHINE bitbake-getvar --value -q --ignore-undefined BBMULTICONFIG)
		# For multiconfig builds, the cve-summary.json is generated for each machine and the multiconfigs. These must
		# be merged to get a complete list of CVEs for the machine.
		if [ -n "$BBMULTICONFIG" ]; then
			for mc in $BBMULTICONFIG; do
				mc_cves="${mc_cves} $(find "${TQEM_YOCTO_TMP_PATH}-${mc}/log" -name "cve-summary.json")"
			done
			machine_cves=$(find "${TQEM_YOCTO_TMP_PATH}/log" -name "cve-summary.json")
			merged_cves="${TQEM_YOCTO_DEPLOY_IMAGES_PATH}/${MACHINE}/em-image-core-${MACHINE}_merged.cve.json"

			# merge multiconfig cves and machine cves
			# shellcheck disable=SC2086
			jq -s '.[0].package=([.[].package]|flatten|unique_by(.name))|.[0]' "$machine_cves" $mc_cves > "$merged_cves"
			ln -srf "$merged_cves" "${TQEM_YOCTO_DEPLOY_IMAGES_PATH}/${MACHINE}/em-image-core-${MACHINE}.cve.json"
		fi
	done
	;;
sbom)
	shift
	for MACHINE in $TQEM_MACHINES; do
		MACHINE="$MACHINE" bitbake \
		-R "$TQEM_ADD_CONF_PATH/create-sbom.conf" \
		"--runonly=do_cyclonedx_package_collect" "$@"

		BBMULTICONFIG=$(MACHINE=$MACHINE bitbake-getvar --value -q --ignore-undefined BBMULTICONFIG)
		if [ -n "$BBMULTICONFIG" ]; then
			for mc in $BBMULTICONFIG; do
				mc_boms="${mc_boms} $(find "${TQEM_YOCTO_TMP_PATH}-${mc}/deploy" -name "bom_${mc}.json")"
			done
			machine_bom=$(find "$TQEM_YOCTO_DEPLOY_PATH" -name "bom_${MACHINE}.json")
			merged_bom="$(dirname "$machine_bom")/$(basename "$machine_bom" .json)_merged.json"

			#merge multiconfig boms and machine bom
			# shellcheck disable=SC2086
			jq -s '.[0].components=([.[].components]|flatten|unique_by(.cpe))|.[0]' "$machine_bom" $mc_boms > "$merged_bom"
		fi
	done
	;;
fill-dl-cache)
	shift
	# Get the source mirror url from bitbake, remove the file:// prefix and resolve the path to an absolute path
	# Allow readlink to fail if no SOURCE_MIRROR_URL is set
	SOURCE_MIRROR_URL=$(bitbake-getvar --value -q --ignore-undefined SOURCE_MIRROR_URL)
	SOURCE_MIRROR_URL=${SOURCE_MIRROR_URL#file://*}
	SOURCE_MIRROR_URL=$(readlink -f "${SOURCE_MIRROR_URL}" || true)

	DL_DIR=$(bitbake-getvar --value -q --ignore-undefined DL_DIR)

	if [ -z "$SKIP_FILL_MIRROR" ] && [ -d "$SOURCE_MIRROR_URL" ]; then
		sync_downloads_to_dlcache "$DL_DIR" "$SOURCE_MIRROR_URL"
	fi
	;;

*)
	for MACHINE in $TQEM_MACHINES; do
		MACHINE="$MACHINE" bitbake -R "${TQEM_ADD_CONF_PATH}/shallow-tarballs.conf" "$@"
	done
	;;
esac
