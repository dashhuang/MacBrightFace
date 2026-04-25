# Changelog

## Unreleased

## 1.0.4

### Fixed

- Made first-launch control panels mark as shown only after successful presentation
- Matched the status-bar popover content to the screen that owns the menu bar item
- Reset control-panel state when popover presentation fails during refresh

## 1.0.3

### Added

- Direct distribution release scripts and notarization documentation
- English-first project README and a dedicated Chinese README
- MIT license and open source contribution guidance
- GitHub issue and CI scaffolding

### Changed

- Reworked the control surface into a popover-based menu bar panel
- Unified brightness, HDR, border size, and on/off state handling
- Improved release build settings for direct macOS distribution

### Fixed

- Reduced crash risk during HDR toggling and slider interaction
- Improved multi-display handling and screen-change updates
- Stopped rebuilding SwiftUI overlay views on every brightness change
