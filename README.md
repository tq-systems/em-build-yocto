# Yocto scripts
## Description
This project manages the Yocto builds for the Energy Manager project. The
required scripts, makefiles and some Gitlab CI/CD templates are maintained
here. The focus is on building the core image and the cross-compiler toolchain.
Furthermore, a docker image is created in order to realize further Yocto builds
with little effort.

## License information
All files in this project are classified as product-specific software and bound
to the use with the TQ-Systems GmbH product: EM400

    SPDX-License-Identifier: LicenseRef-TQSPSLA-1.0.3

## Local layer configuration
The build can be adapted by a local layer configuration which is already
introduced by the `em-build` project.

### Configuration file
Create a local layer configuration file (e.g. `adapt-em-layers.conf`).
Set the environment variable `LOCAL_LAYER_CONF` to the path of the file,
it has to be relative the root directory of the project.

Furthermore this configuration file can be adjusted by the environment variable
`ADD_LOCAL_CONF`, it's content is appended to configuration file.

### Configuration variable
Set the environment variable `OVERRIDE_LOCAL_CONF` to create a local layer
configuration. It overrides an already existing configuration file,
if it exists.

## Release of yocto-scripts
A release commit updates at least the changelogs. It is also possible to adjust
the `base-ci` reference in the `.gitlab-ci.yml` file, since a release requires
tagged versions.

A release build is triggered by pushing a tag.

## Release of core image and cross-compiler toolchain
A release build is triggered by pushing a tag from the `em-build` project with
the `em-build_` prefix. For example, if the em-build tag `v1.2.3` is to be
built, the tag `em-build_v1.2.3` must be pushed here.

## Retrigger of release build
To restart a release build or single steps of a release build a manual
release can be started in the Pipeline
To trigger a complete release RELEASE_STEP has to be set to `release`.
To trigger single steps of the release RELEASE_STEP has to be set to one
of the following:
* `prepare`
* `release-fetch`
* `release-build`
* `release-deploy`

Setting CLEAN_DEPLOY_DIR allows deleting the deploy directory. This is
useful when an relase job failed and left behind incomplete deploy dir
or when the release-deploy step has to be repeated.
