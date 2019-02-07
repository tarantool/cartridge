# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.2] - 2019-02-07

### Fixed

- Minor internal corner cases

## [0.6.1] - 2019-02-05

### Fixed

- UI/UX: Replace "bootstrap vshard" button with a noticable panel
- UI/UX: Replace failover panel with a small button

## [0.6.0] - 2019-01-30

### Fixed

- Ability to disable vshard-storage role when zero-weight rebalancing finishes
- Active master indication during failover
- Other minor improvements

### Changed

- New frontend core
- Dependencies update
- Call to `join_server` automatically does `probe_server`

### Added

- Servers filtering by roles, uri, alias in WebUI

## [0.5.1] - 2018-12-12

### Fixed

- WebUI errors

## [0.5.0] - 2018-12-11

### Fixed

- Graphql mutations order

### Changed

- Callbacks in user-defined roles are called with `is_master` parameter,
  indicating state of the instance
- Combine `cluster.init` and `cluster.register_role` api calls in single `cluster.cfg`
- Eliminate raising exceptions
- Absorb http server in `cluster.cfg`

### Added

- Support of vshard replicaset weight parameter
- `join_server()` `timeout` parameter to make call synchronous

## [0.4.0] - 2018-11-27
### Fixed/Improved
- Uncaught exception in WebUI
- Indicate when backend is unavailable
- Sort servers in replicaset, put master first
- Cluster mutations are now synchronous, except joining new servers

### Added
- Lua API for temporarily disabling servers
- Lua API for implementing user-defined roles

## [0.3] - 2018-10-30
### Changed
- Config structure incompatible with v0.2

### Added
- Explicit vshard master configuration
- Automatic failover (switchable)
- Unit tests

## [0.2] - 2018-10-01
### Changed
- Allow vshard bootstrapping from ui
- Several stability improvements

## [0.1] - 2018-09-25
### Added
- Basic functionality
- Integration tests
- Luarock-based packaging
- Gitlab CI integration
