## [1.2.2] - 2026-07-24
### Changed
- license-clearing: exclude util-linux-libuuid

## [1.2.1] - 2026-05-22
### Changed
- Update base reference to v3.1.0

## [1.2.0] - 2026-05-13
### Changed
- Update base reference to v3.0.0

## [1.1.0] - 2026-04-01
### Fixed
- license-clearing.conf: replace em-license-header with em-license-compliance

### Changed
- Update base reference to v2.2.1
- release.sh: fetch: use multi-core compression with pigz when available

## [1.0.3] - 2026-03-25
### Fixed
- license-clearing.conf: disable license-header generation

## [1.0.2] - 2026-03-23
### Fixed
- gitlab-ci.yml: fix deploy path of tagged builds

## [1.0.1] - 2026-03-17
### Added
- release.sh: added support for ubuntu 22.04's copy command

### Changed
- ci/include: update base image

## [1.0.0] - 2026-03-16
### Changed
- handle_local_layer_conf: improved descriptive variable names
- docker: removed archive_bootloader creation

### Added
- .gitlab-ci.yml: add release job
