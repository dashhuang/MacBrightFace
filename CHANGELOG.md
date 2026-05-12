# Changelog

## Unreleased

## 1.0.6

### Added

- Added background-friendly operation so DisplayFill can stay resident in the menu bar.
- Added per-display camera activation automation that can turn fill light on when a camera starts.
- Added launch-at-login and HDR controls to the options menu.

### Changed

- Lowered the minimum fill-light brightness for HDR and effect modes.
- Lowered the minimum fill-light size to 30 px.
- Reduced idle memory usage by releasing overlay windows and Metal render resources after lights turn off.
- Improved menu foreground behavior on the screen under the pointer and secondary-panel top alignment.

### Fixed

- Fixed several multi-display menu refresh and sizing edge cases.
- Removed unused localization keys from the app strings files.

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
