# Changelog

All notable changes to Grabby. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- A glowing trail behind the pointer while the action button is held, in the icon's colours, fading over half a second. On by default; toggle in Settings, General.

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
