PATH_EM_YOCTO ?= /opt/energy-manager/yocto
include $(PATH_EM_YOCTO)/environment.mk


# Snapshot
all: prepare build

prepare: enable-clean-up
	$(SCRIPT_PREPARE)

build:
	$(SCRIPT_BUILD) $(TARGET)
	$(SCRIPT_BUILD) fill-dl-cache

deploy-artifact:
	$(SCRIPT_DEPLOY) artifact $(TARGET)

deploy-images:
	$(SCRIPT_DEPLOY) images $(MACHINE) $(LINK_LIST)

copy-bundle-artifacts:
	$(SCRIPT_COPY_BUNDLE_ARTIFACTS) $(TARGET) $(TARGET_DIR)

# Release
release-fetch:
	$(SCRIPT_RELEASE) fetch

release-build:
	$(SCRIPT_RELEASE) build

release-deploy:
	$(SCRIPT_RELEASE) deploy

# A single release job prevents that another job may barge in between
release: prepare release-fetch release-build release-deploy

release-test:
	$(SCRIPT_RELEASE) test $(STEP)

# Clean up
EXEC_CLEAN_BUILD := rm -rf $(DIR_YOCTO_BUILD)
EXEC_CLEAN_FULL  := rm -rf $(DIR_EM_BUILD)

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

clean-deploy-dir:
	$(SCRIPT_RELEASE) clean-deploy-dir

.NOTPARRALEL: all release
.PHONY: all prepare build deploy \
	release-build release-deploy release release-test \
	enable-clean-up clean-build clean
