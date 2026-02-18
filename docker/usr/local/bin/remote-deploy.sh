#!/bin/bash

set -eo pipefail

# shellcheck disable=SC2034
SCRIPT_NAME=$(basename "$0")

# source shell library for logging functions
# shellcheck source=/dev/null
. /usr/local/lib/tqem/shell/log.sh

usage() {
	echo "NAME

       $SCRIPT_NAME - deploy a directory to a remote server

SYNOPSIS

       $SCRIPT_NAME SOURCE_DIR SERVER:DESTINATION_DIR [OPTIONS]

DESCRIPTION

       The script deploys a directory content to a folder on a remote server via SSH.

       -o, --overwrite
              Overwrite existing files on the remote server
"
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	usage; exit 0
fi

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
	usage; exit 1
fi

SOURCE_DIR="$1"
DESTINATION_DIR="$2"

ADD_RSYNC_OPTION="--ignore-existing"
if [ "$3" = "-o" ] || [ "$3" = "--overwrite" ]; then
	unset ADD_RSYNC_OPTION
fi

SERVER=$(echo "$DESTINATION_DIR" | cut -d: -f1)
REMOTE_DIR=$(echo "$DESTINATION_DIR" | cut -d: -f2-)


tqem_log_info "Deploying directory $SOURCE_DIR to $SERVER:$REMOTE_DIR"

# ssh options need to be set locally in ~/.ssh/config
ssh "$SERVER" mkdir -p "$REMOTE_DIR"
# shellcheck disable=SC2086
rsync -zav --links $ADD_RSYNC_OPTION "$SOURCE_DIR/" "$SERVER:$REMOTE_DIR/"
