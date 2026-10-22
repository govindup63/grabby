# Changelog

All notable changes to Grabby. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.3] - 2026-10-23

### Fixed

- Desktop sliding did nothing on macOS 26: the app only knew the macOS 27 event format. On macOS 26 and earlier it now sends the older field-based format that Mac Mouse Fix ships for those versions, with that format's scale and direction rules. This path has not been verified on real hardware by the project yet; report direction or speed problems with the macOS version.

## [0.1.2] - 2026-10-23

### Fixed

- On a fresh Mac, Grabby did not appear in System Settings > Privacy & Security > Accessibility, so there was nothing to switch on. It now asks macOS for access at launch, which adds it to the list and shows the system prompt. The onboarding text also explains the + button.

## [0.1.1] - 2026-10-23

Same gestures as 0.1.0; this release carries the app identity and the project tooling.

### Added

- App icon and a template menu bar icon (a pointer with motion trails).
- README, MIT license, contributor guide, changelog, CI on a macOS runner and tagged releases.

### Changed

- Builds on machines with Xcode as well as Command Line Tools only.

## [0.1.0] - 2026-10-18

First release.

### Added

- Hold the action button and slide between desktops with the pointer, matching the trackpad's three-finger swipe on macOS 27 (measured against real trackpad events).
- Drag up for Mission Control, drag down to return to the app.
- Hold plus left click for the area screenshot, hold plus right click for the screenshot and recording panel.
- Learn step to choose the action button; left and right are refused.
- Direction and Throw settings, optional tap action, launch at login.
- Accessibility onboarding that starts working the moment access is granted.
- Conflict notices when Logitech G HUB, Logi Options+ or BetterMouse is running.
- Keyboard-shortcut fallback for genuine private-API failures.
- `grabby-probe` developer CLI and a file-based gesture trace for debugging.
