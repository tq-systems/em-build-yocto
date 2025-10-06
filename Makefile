# This Makefile is executable inside and outside the docker container

export TQEM_YOCTO_PROJECT_PATH = $(CURDIR)

# Default path for the Makefile inside the container
TQEM_DEFAULT_OPT_YOCTO_PATH ?= /opt/energy-manager/yocto

# If "$TQEM_DEFAULT_OPT_YOCTO_PATH/Makefile" exists, we are in the container
ifneq ($(wildcard $(TQEM_DEFAULT_OPT_YOCTO_PATH)/Makefile),)
  TQEM_OPT_YOCTO_PATH = $(TQEM_DEFAULT_OPT_YOCTO_PATH)
else
  # The PATH variable is extended for running the scripts outside the container
  BIN_DIR = $(TQEM_YOCTO_PROJECT_PATH)/docker/usr/local/bin
  ifeq ($(findstring $(BIN_DIR),$(PATH)),)
    export PATH := $(PATH):$(BIN_DIR)
  endif

  TQEM_OPT_YOCTO_PATH = $(TQEM_YOCTO_PROJECT_PATH)/docker$(TQEM_DEFAULT_OPT_YOCTO_PATH)
endif

include $(TQEM_OPT_YOCTO_PATH)/Makefile
