# The default machine is 'em-aarch64', multi-machine builds are maintained in the CI
export TQEM_MACHINES ?= em-aarch64

# The build time of the em-aarch64 machine can be reduced by setting the explicit
# em-aarch64 machine (em4xx or em-cb30)
export TQEM_EM_AARCH64_MACHINE ?=

# em-build git repository
export TQEM_EM_BUILD_GIT_REPO ?= https://github.com/tq-systems/em-build.git

# The project itself has regular semantic versions.
# So that the em-build tags can be referenced in this git repository, a git tag
# convention is introduced. If the tag has the prefix 'em-build_', the git tag
# of em-build is derived from it.

ifneq ($(strip ${BUILD_TAG}),)
  DERIVE_TAG = $(shell echo ${BUILD_TAG} | grep  ^em-build_ | sed -e 's/em-build_//g')
  ifneq ($(DERIVE_TAG),)
    TQEM_EM_BUILD_REF = $(DERIVE_TAG)
  endif
endif
export TQEM_EM_BUILD_REF ?= master

# Directories
export TQEM_EM_BUILD_DIR            ?= em-build
export TQEM_YOCTO_BUILD_DIR          = $(TQEM_EM_BUILD_DIR)/build
export TQEM_YOCTO_CONF_DIR           = $(TQEM_YOCTO_BUILD_DIR)/conf
export TQEM_YOCTO_DOWNLOADS_DIR      = $(TQEM_YOCTO_BUILD_DIR)/downloads
export TQEM_YOCTO_TMP_DIR            = $(TQEM_YOCTO_BUILD_DIR)/tmp
export TQEM_YOCTO_WORK_DIR           = $(TQEM_YOCTO_TMP_DIR)/work
export TQEM_YOCTO_DEPLOY_DIR         = $(TQEM_YOCTO_TMP_DIR)/deploy
export TQEM_YOCTO_DEPLOY_SDK_DIR     = $(TQEM_YOCTO_DEPLOY_DIR)/sdk
export TQEM_YOCTO_DEPLOY_IMAGES_DIR  = $(TQEM_YOCTO_DEPLOY_DIR)/images
export TQEM_YOCTO_DEPLOY_SOURCES_DIR = $(TQEM_YOCTO_DEPLOY_DIR)/sources
export TQEM_YOCTO_DEPLOY_SPDX_DIR    = $(TQEM_YOCTO_DEPLOY_DIR)/spdx

export TQEM_SNAPSHOTS_DIR ?= snapshots
export TQEM_RELEASES_DIR  ?= releases

export TQEM_ARTIFACTS_DIR ?= artifacts
export TQEM_DEPLOY_DIR    ?= deploy

export TQEM_GIT_REF_SUBDIR          ?= $(TQEM_EM_BUILD_REF)
export TQEM_BUILD_TYPE_SUBDIR       ?= $(TQEM_SNAPSHOTS_DIR)
export TQEM_MACHINE_OVERRIDE_SUBDIR ?=

# Paths
export TQEM_ADD_CONF_PATH = $(TQEM_OPT_YOCTO_PATH)/conf

# ATTENTION: TQEM_BASE_DEPLOY_PATH is the base deployment path,
# it should be customized according to the user's needs.
export TQEM_BASE_DEPLOY_PATH ?= $(HOME)/workspace/tqem/deploy
export TQEM_EMOS_DEPLOY_PATH ?= $(TQEM_BASE_DEPLOY_PATH)/$(TQEM_BUILD_TYPE_SUBDIR)/emos/$(TQEM_GIT_REF_SUBDIR)

export TQEM_ARTIFACTS_PATH            = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_ARTIFACTS_DIR)
export TQEM_EM_BUILD_PATH             = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_EM_BUILD_DIR)
export TQEM_YOCTO_BUILD_PATH          = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_BUILD_DIR)
export TQEM_YOCTO_CONF_PATH           = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_CONF_DIR)
export TQEM_YOCTO_DOWNLOADS_PATH      = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_DOWNLOADS_DIR)
export TQEM_YOCTO_TMP_PATH            = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_TMP_DIR)
export TQEM_YOCTO_WORK_PATH           = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_WORK_DIR)
export TQEM_YOCTO_DEPLOY_PATH         = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_DEPLOY_DIR)
export TQEM_YOCTO_DEPLOY_SDK_PATH     = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_DEPLOY_SDK_DIR)
export TQEM_YOCTO_DEPLOY_IMAGES_PATH  = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_DEPLOY_IMAGES_DIR)
export TQEM_YOCTO_DEPLOY_SOURCES_PATH = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_DEPLOY_SOURCES_DIR)
export TQEM_YOCTO_DEPLOY_SPDX_PATH    = $(TQEM_YOCTO_PROJECT_PATH)/$(TQEM_YOCTO_DEPLOY_SPDX_DIR)

# ADD_LAYER_CONF_FILE is a file that provides an additional set of Yocto layers
# that is appended to the internal static set of em-layers.conf
# ADD_LAYER_CONF_PATH is determined relative to this project's root directory
ifdef ADD_LAYER_CONF_FILE
  export ADD_LAYER_CONF_PATH = $(shell realpath --relative-to=$(TQEM_YOCTO_PROJECT_PATH) $(ADD_LAYER_CONF_FILE))
endif

# Enable further local configurations (currently only site.conf)
export PATH_LOCAL_YOCTO_CONF ?= $(HOME)/.yocto

# Files
export PREPARE_SCRIPT               = prepare.sh
export BUILD_SCRIPT                 = build.sh

export TQEM_YOCTO_LOCAL_CONF        = $(TQEM_YOCTO_CONF_PATH)/local.conf
