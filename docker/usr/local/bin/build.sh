#!/bin/bash

set -e

DIR_SCRIPT=$(dirname "$0")
# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")
# shellcheck source=/dev/null
. "$DIR_SCRIPT/functions.sh"

[ $# -lt 1 ] && log_error "Missing target(s)"

# shellcheck disable=SC2153
log_info "Build with the following parameters:
build targets:      $*
machines:           $MACHINES
em-build reference: $REF_EM_BUILD
"

# shellcheck disable=SC2034
BB_ENV_PASSTHROUGH_ADDITIONS='ACCEPT_FSL_EULA'
export ACCEPT_FSL_EULA='1'

cd_em_build
setup_build_environment
setup_local_yocto_conf

case $1 in
toolchain)
    for MACHINE in $MACHINES; do
        ARCHITECTURE="${TOOLCHAINS[$MACHINE]}"
        if [ -n "$ARCHITECTURE" ]; then
            MACHINE="$MACHINE" bitbake \
                -R "${PATH_EM_YOCTO_CONF}/shallow-tarballs.conf" \
                em-image-core -c populate_sdk

            # link the toolchain artifact to simplify its deployment
            TOOLCHAIN_PATTERN="emos-x86_64-${ARCHITECTURE}-toolchain"
            PATH_TOOLCHAIN=$(find "${PATH_YOCTO_DEPLOY_SDK}" -type f -name "*${TOOLCHAIN_PATTERN}*.sh")

            [ -e "$PATH_TOOLCHAIN" ] || log_error "Cannot find toolchain: $TOOLCHAIN_PATTERN"
            FILE_TOOLCHAIN="$(basename "$PATH_TOOLCHAIN")"
            ln -sf "$FILE_TOOLCHAIN" "${PATH_YOCTO_DEPLOY_SDK}/${TOOLCHAIN_PATTERN}.sh"
        fi
    done
    ;;
cve)
    shift
    for MACHINE in $MACHINES; do
        MACHINE="$MACHINE" bitbake \
        -R "$PATH_EM_YOCTO_CONF/check-vulnerabilities.conf" "$@"

        BBMULTICONFIG=$(MACHINE=$MACHINE bitbake-getvar --value -q --ignore-undefined BBMULTICONFIG)
        # For multiconfig builds, the cve-summary.json is generated for each machine and the multiconfigs. These must
        # be merged to get a complete list of CVEs for the machine.
        if [ -n "$BBMULTICONFIG" ]; then
            for mc in $BBMULTICONFIG; do
                mc_cves="${mc_cves} $(find "${PATH_YOCTO_TMP}-${mc}/log" -name "cve-summary.json")"
            done
            machine_cves=$(find "${PATH_YOCTO_TMP}/log" -name "cve-summary.json")
            merged_cves="${PATH_YOCTO_DEPLOY_IMAGES}/${MACHINE}/em-image-core-${MACHINE}_merged.cve.json"

            # merge multiconfig cves and machine cves
            # shellcheck disable=SC2086
            jq -s '.[0].package=([.[].package]|flatten|unique_by(.name))|.[0]' "$machine_cves" $mc_cves > "$merged_cves"
            ln -srf "$merged_cves" "${PATH_YOCTO_DEPLOY_IMAGES}/${MACHINE}/em-image-core-${MACHINE}.cve.json"
        fi
    done
    ;;
sbom)
    shift
    for MACHINE in $MACHINES; do
        MACHINE="$MACHINE" bitbake \
        -R "$PATH_EM_YOCTO_CONF/create-sbom.conf" \
        "--runonly=do_cyclonedx_package_collect" "$@"

        BBMULTICONFIG=$(MACHINE=$MACHINE bitbake-getvar --value -q --ignore-undefined BBMULTICONFIG)
        if [ -n "$BBMULTICONFIG" ]; then
            for mc in $BBMULTICONFIG; do
                mc_boms="${mc_boms} $(find "${PATH_YOCTO_TMP}-${mc}/deploy" -name "bom_${mc}.json")"
            done
            machine_bom=$(find "$PATH_YOCTO_DEPLOY" -name "bom_${MACHINE}.json")
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
    for MACHINE in $MACHINES; do
        MACHINE="$MACHINE" bitbake \
            -R "${PATH_EM_YOCTO_CONF}/shallow-tarballs.conf" \
            "$@"
    done
    ;;
esac
