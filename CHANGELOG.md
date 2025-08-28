## [v1.3.0] - 2025-06-05
### Added
- Change to new gitlab-runner tq-em-yocto-fast
- Add support for source mirror and filling the mirror
- Add support to use a server specific configuration
- Add SPDX data to the deployable artifacts
- Use shallow tarball for source mirror
- exclude python3 packages from archiver class to reduce license-clearing effort

## [v1.2.2] - 2025-02-27
### Changed
- Updates for Yocto Scarthgap

## [v1.2.1] - 2025-02-04
### Added
- Create bom on release with meta-cyclonedx

## [v1.2.0] - 2024-11-28
### Added
- trigger for toolchain snapshot builds
- script to copy all bundle artifacts
- merge request template
- Allow manual release steps

### Changed
- remove imx8mn-egw builds
- move cleanup enablement from before_script to make target
- split prepare and build steps

### Fixed
- shellcheck errors in copy-bundle-artifacts

## [v1.1.0] - 2024-04-26
### Added
- support for em-aarch64 machine and separate bootloader archive

### Changed
- implemented workaround for windows filesystems which cannot handle symlinks

## [v1.0.0] - 2024-04-26
