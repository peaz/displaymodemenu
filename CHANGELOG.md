# Changelog

All notable changes to DisplayMode Menu will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2] - 2025-12-26

### Added
- Settings window for customizing favorite display modes
- Ability to configure which modes appear in the favorites section
- Minimum refresh rate filter for "All Modes" list
- Toggle for low-resolution mode visibility
- Reset to default favorites button (22 common display resolutions)
- Click-to-copy display name functionality in menu
- Display mode validation to ensure requested modes are available
- Per-display submenus showing all available modes ≥60Hz
- Current display mode highlighting in bold, blue font
- Dual-format support for Shortcuts integration:
  - Settings format: `width,height,refreshRate,hiDPI` (e.g., `2560,1440,60,true`)
  - Legacy format: `WIDTHxHEIGHT[@REFRESH]` (e.g., `1920x1080@60`)
- Comprehensive default favorites list with 22 common resolutions
- Improved installation instructions with quarantine removal command

### Changed
- Reorganized menu with favorites pinned at top
- Enhanced Shortcuts integration with better display name handling for multi-display setups
- Improved menu organization and mode filtering
- Optimized display mode detection and switching

### Fixed
- Display mode validation to prevent invalid mode switches
- Better handling of multi-display configurations
- Improved refresh rate filtering

## [0.1] - Initial Release

### Added
- Basic menu bar app for switching display resolutions
- Shortcuts integration for automation
- Support for HiDPI modes
- Multi-display support
- Display mode enumeration and switching
