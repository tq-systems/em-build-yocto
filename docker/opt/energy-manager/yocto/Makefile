TQEM_OPT_YOCTO_PATH ?= /opt/energy-manager/yocto
include $(TQEM_OPT_YOCTO_PATH)/environment.mk

# Snapshot
all: prepare
	$(BUILD_SCRIPT) core-image
	$(BUILD_SCRIPT) toolchain

prepare: enable-clean-up
	$(PREPARE_SCRIPT)

build: prepare
	$(BUILD_SCRIPT) $(TARGET)

deploy:
	tqem-copy.sh $(TQEM_ARTIFACTS_PATH) $(TQEM_EMOS_DEPLOY_PATH) --overwrite

# Clean up
EXEC_CLEAN_BUILD := rm -rf $(TQEM_YOCTO_BUILD_DIR)
EXEC_CLEAN_FULL  := rm -rf $(TQEM_EM_BUILD_DIR)

enable-clean-up:
ifeq ($(CLEAN_MODE),build)
	$(EXEC_CLEAN_BUILD)
endif
ifeq ($(CLEAN_MODE),full)
	$(EXEC_CLEAN_FULL)
endif

clean-build:
	$(EXEC_CLEAN_BUILD)

clean:
	$(EXEC_CLEAN_FULL)

.PHONY: all prepare build deploy \
	enable-clean-up clean-build clean
