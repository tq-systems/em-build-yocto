TQEM_OPT_YOCTO_PATH ?= /opt/energy-manager/yocto
include $(TQEM_OPT_YOCTO_PATH)/environment.mk

# Snapshot
all: prepare
	$(BUILD_SCRIPT) core-image
	$(BUILD_SCRIPT) toolchain

prepare: enable-clean-up
	$(EXEC_CLEAN_ARTIFACTS)
	$(PREPARE_SCRIPT)

build: prepare
	$(BUILD_SCRIPT) $(TARGET)

snapshot-deploy:
	tqem-copy.sh $(TQEM_ARTIFACTS_PATH) $(TQEM_EMOS_DEPLOY_PATH) --overwrite

release-prepare: prepare
	$(RELEASE_SCRIPT) fetch

release: clean-artifacts release-prepare
	$(RELEASE_SCRIPT) build
	$(RELEASE_SCRIPT) collect

release-deploy:
	tqem-copy-safe.sh $(TQEM_ARTIFACTS_PATH) $(TQEM_EMOS_DEPLOY_PATH)

release-test:
	$(RELEASE_SCRIPT) test $(FUNCTION)

mirror:
	$(RELEASE_SCRIPT) mirror

# Clean up
EXEC_CLEAN_ARTIFACTS := rm -rf $(TQEM_ARTIFACTS_DIR) $(TQEM_DEPLOY_DIR)
EXEC_CLEAN_BUILD := rm -rf $(TQEM_YOCTO_BUILD_DIR)
EXEC_CLEAN_FULL  := rm -rf $(TQEM_EM_BUILD_DIR)

enable-clean-up:
ifeq ($(CLEAN_MODE),build)
	$(EXEC_CLEAN_BUILD)
endif
ifeq ($(CLEAN_MODE),full)
	$(EXEC_CLEAN_FULL)
endif

clean-artifacts:
	$(EXEC_CLEAN_ARTIFACTS)

clean-build:
	$(EXEC_CLEAN_BUILD)

clean:
	$(EXEC_CLEAN_FULL)

.PHONY: all prepare build snapshot-deploy \
	release-prepare release release-deploy release-test \
	enable-clean-up clean-build clean-artifacts clean
