# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed/Improved
- Uncaught exception in WebUI
- Indicate when backend is unavailable
- Sort servers in replicaset, put master first

### Added
- API for temporarily disabling servers

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
