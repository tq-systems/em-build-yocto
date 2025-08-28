# This Makefile needs to be executable outside the docker container to enable local builds

PATH_PROJECT_ROOT = $(CURDIR)
# Default path for the Makefile inside the container
PATH_CHECK = /opt/energy-manager/yocto

# If PATH_CHECK exists, we are in the container
ifneq ($(wildcard $(PATH_CHECK)/Makefile),)
  PATH_EM_YOCTO = $(PATH_CHECK)
else
  # The PATH variable is extended for running the scripts outside the container
  DIR_BIN = $(PATH_PROJECT_ROOT)/docker/usr/local/bin
  ifeq ($(findstring $(DIR_BIN),$(PATH)),)
    export PATH := $(PATH):$(DIR_BIN)
  endif

  PATH_EM_YOCTO = $(PATH_PROJECT_ROOT)/docker$(PATH_CHECK)
endif

include $(PATH_EM_YOCTO)/Makefile
