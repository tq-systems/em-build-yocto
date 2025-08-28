# Export project root directory
export PATH_PROJECT_ROOT ?= $(CURDIR)

# The default machine is 'em-aarch64', multi-machine builds are maintained in the CI
export MACHINES ?= em-aarch64

# Git
export GIT_EM_BUILD ?= https://github.com/tq-systems/em-build.git

# The project itself has regular semantic versions.
# So that the em-build tags can be referenced in this git repository, a git tag
# convention is introduced. If the tag has the prefix 'em-build_', the git tag
# of em-build is derived from it.
ifdef CI_COMMIT_TAG
  DERIVE_TAG = $(shell echo ${CI_COMMIT_TAG} | grep  ^em-build_ | sed -e 's/em-build_//g')
  ifneq ($(DERIVE_TAG),)
    REF_EM_BUILD = $(DERIVE_TAG)
  endif
endif
export REF_EM_BUILD ?= master

# Directories
export DIR_EM_BUILD            ?= em-build
export DIR_YOCTO_BUILD          = $(DIR_EM_BUILD)/build
export DIR_YOCTO_DOWNLOADS      = $(DIR_YOCTO_BUILD)/downloads
export DIR_YOCTO_TMP            = $(DIR_YOCTO_BUILD)/tmp
export DIR_YOCTO_WORK           = $(DIR_YOCTO_TMP)/work
export DIR_YOCTO_DEPLOY         = $(DIR_YOCTO_TMP)/deploy
export DIR_YOCTO_DEPLOY_SDK     = $(DIR_YOCTO_DEPLOY)/sdk
export DIR_YOCTO_DEPLOY_IMAGES  = $(DIR_YOCTO_DEPLOY)/images
export DIR_YOCTO_DEPLOY_SOURCES = $(DIR_YOCTO_DEPLOY)/sources
export DIR_YOCTO_DEPLOY_SPDX    = $(DIR_YOCTO_DEPLOY)/spdx

export DIR_SNAPSHOTS = snapshots
export DIR_RELEASES  = releases

export SUBDIR_REF        ?= $(REF_EM_BUILD)
export SUBDIR_BUILD_TYPE ?= $(DIR_SNAPSHOTS)
export SUBDIR_MACHINE_OVERRIDE ?=

# Paths
export PATH_EM_YOCTO_CONF = $(PATH_EM_YOCTO)/conf

# ATTENTION: PATH_BASE_DEPLOY is the base deployment path,
# it should be customized according to the user's needs.
export PATH_BASE_DEPLOY ?= $(HOME)/workspace/deploy

export PATH_EM_BUILD             = $(PATH_PROJECT_ROOT)/$(DIR_EM_BUILD)
export PATH_YOCTO_BUILD          = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_BUILD)
export PATH_YOCTO_DOWNLOADS      = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_DOWNLOADS)
export PATH_YOCTO_TMP            = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_TMP)
export PATH_YOCTO_WORK           = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_WORK)
export PATH_YOCTO_DEPLOY         = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_DEPLOY)
export PATH_YOCTO_DEPLOY_SDK     = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_DEPLOY_SDK)
export PATH_YOCTO_DEPLOY_IMAGES  = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_DEPLOY_IMAGES)
export PATH_YOCTO_DEPLOY_SOURCES = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_DEPLOY_SOURCES)
export PATH_YOCTO_DEPLOY_SPDX    = $(PATH_PROJECT_ROOT)/$(DIR_YOCTO_DEPLOY_SPDX)

# Enables adding or overriding yocto layer definitions,
# RELPATH_LOCAL_CONF is relative to the project's root directory
ifdef RELPATH_LOCAL_CONF
  export PATH_LOCAL_CONF = $(PATH_PROJECT_ROOT)/$(RELPATH_LOCAL_CONF)
endif

export PATH_LOCAL_YOCTO_CONF ?= $(HOME)/local-yocto-config

# Files
export SCRIPT_PREPARE = prepare.sh
export SCRIPT_BUILD   = build.sh
export SCRIPT_DEPLOY  = deploy.sh
export SCRIPT_COPY_BUNDLE_ARTIFACTS = copy-bundle-artifacts.sh
export SCRIPT_RELEASE = release.sh

# Linking
export DEPLOY_SYMLINK ?= false
export DEPLOY_SUFFIX  ?= latest
