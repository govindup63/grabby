<p align="center">
  <img src="docs/logo/grabby.png" width="160" alt="Grabby icon: a pointer with motion trails">
</p>

<h1 align="center">Grabby</h1>

<p align="center">
  One spare mouse button becomes the trackpad's three-finger swipe.<br>
  Hold it and slide between desktops. Up for Mission Control, down to come back. Click while holding for screenshots.
</p>

<p align="center">
  <a href="https://github.com/govindup63/grabby/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/govindup63/grabby/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/govindup63/grabby/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/govindup63/grabby?display_name=tag"></a>
  <img alt="macOS 26 or later" src="https://img.shields.io/badge/macOS-26%2B-black">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138">
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

## What it does

If you use a regular mouse on a Mac, moving between desktops means Control+Arrow or a trip to the trackpad. Grabby gives one of your mouse's extra buttons the job the three-finger swipe has on a trackpad, and it feels the same: the desktops move with your hand, you can change your mind mid-drag, and letting go settles on the nearest one.

Hold the action button and move:

| Motion | Result |
|---|---|
| Left or right | Desktops slide under the pointer. One screen width of hand travel is one desktop. Release past halfway to complete, short of it to slide back. |
| Up | Mission Control. |
| Down | Back to your app (closes Mission Control if it is open; otherwise nothing). |
| Left click while holding | The system area screenshot (what Command Shift 4 does). |
| Right click while holding | The screenshot and recording panel (Command Shift 5). |

A tap on the button does nothing unless you choose otherwise in Settings. If you are already dragging something with the left or right button, Grabby stays out of the way completely.

It is a menu bar app with no Dock icon, 0% CPU when idle and around 50 MB of memory. There is one Settings window and nothing else.

## Install

Grabby is distributed outside the Mac App Store because it needs Accessibility access and posts synthetic input, which the sandbox does not allow.

1. Download `Grabby.app.zip` from the [latest release](https://github.com/govindup63/grabby/releases/latest) and unzip it into `/Applications`.
2. Open it. Releases are signed ad hoc, so the first launch needs a right-click, Open.
3. Grabby asks for Accessibility access. Turn it on in System Settings > Privacy & Security > Accessibility (if Grabby is not listed, add it with the + button); Grabby starts working within a couple of seconds, no relaunch.
4. In Settings (menu bar icon, Settings...), press Change and press the mouse button you want. Left and right are refused.

If your mouse software (Logitech G HUB, Logi Options+, BetterMouse) has an assignment on that button, set it back to default there, or the click never reaches Grabby. Settings shows a notice when one of these is running.

Or build it yourself; see Development below. Needs macOS 26 or later. Built and tested on macOS 27; on macOS 26 the gesture uses the older event format and has had less testing.

## Settings

- **Action button**: which button, chosen by pressing it.
- **Direction**: follow the system's natural scrolling (default), or force natural or reversed.
- **Throw**: at zero, where you let go decides. Further right, the speed of your hand at release counts, so a flick can finish the move.
- **Tap without moving**: nothing (default), Mission Control, App Expose, Show Desktop, or pass the click through to the app under the pointer.
- **Launch at login.**

Settings live in `~/Library/Application Support/Grabby/settings.json`.

## How it works

The short version: Grabby synthesises the same event a trackpad sends.

- A `CGEventTap` on the HID event stream swallows the action button's down and up. A second, listen-only tap reads pointer travel while the button is held, and switches off on release, which is why idle cost is zero.
- The slide is a Dock Swipe gesture, the private event the Dock uses for three-finger swipes. Grabby builds an `IOHIDEvent` (type 23: motion, flavor, progress), attaches it to a type-30 `CGEvent` through SkyLight's `SLEventSetIOHIDEvent`, and posts it at the session level, one update per frame of the display under the pointer. The Dock animates the Spaces strip against the progress value exactly as it does for the trackpad.
- Release reports the hand's velocity in a child Velocity event, and the Dock decides whether to commit or slide back, the same rule a trackpad gets.
- All private API is declared in one C target and resolved with `dlsym` at launch. If a symbol is missing on a future macOS, Grabby degrades to triggering the system's own Mission Control and Space-switching actions through their symbolic hotkeys instead of crashing or doing nothing.
- Mission Control being open is detected from the Dock's full-display window, which is what decides whether a downward drag has anything to close.

The event format, scale (one desktop = progress 1.0) and sign conventions were measured by recording a real trackpad on macOS 27 with the same tap mechanism; they differ from what older tools assume. The measurements are written up in [specs/001-mouse-action-button/research.md](specs/001-mouse-action-button/research.md).

Everything that can be reasoned about without a mouse (gesture recognition, scaling, coalescing, release velocity, fallback decisions, settings) lives in `GrabbyCore`, a library with no AppKit dependency, and is covered by tests written before the code.

## Development

Requirements: macOS 26 or later with the Command Line Tools (Xcode is not needed) and Swift 6.

```bash
swift test                 # unit tests (Swift Testing)
scripts/run-dev.sh         # build release, bundle and sign Grabby.app, relaunch it
swift run grabby-probe --symbols   # are the private symbols present on this macOS?
swift run grabby-probe --spaces    # displays and Space counts as macOS reports them
```

`scripts/bundle.sh` signs with the first Developer ID or Apple Development identity in your keychain, or ad hoc with `GRABBY_SIGN_IDENTITY=-`. On a development machine a stable identity matters: the Accessibility grant is keyed to the code signature, so an ad-hoc build loses it on every rebuild.

Debugging gestures: create `~/Library/Application Support/Grabby/trace.log` and relaunch. Grabby then appends a trace of every gesture decision and, through a listen tap, every Dock Swipe event in the session, real or synthetic, with its IOHIDEvent fields. That is how the trackpad comparison above was made. Delete the file to turn it off.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and conventions.

### Layout

```text
Package.swift                 SwiftPM manifest: four targets and the test target
Sources/
  GrabbyCore/                 pure gesture logic, no AppKit; fully unit-tested
  GrabbyPrivate/              the only place private macOS API is named; dlsym resolvers (C)
  GrabbyEngines/              Dock Swipe engine, hotkey engine, Space observer, logging, trace
  GrabbyApp/                  menu bar app: taps, permissions, settings UI, learn step, conflicts
  GrabbyProbe/                grabby-probe developer CLI
Tests/GrabbyCoreTests/        Swift Testing suites for GrabbyCore
assets/                       icon sources (SVG) and the renderer that produces .icns and menu bar PNGs
scripts/                      bundle.sh (build, bundle, sign), run-dev.sh
docs/logo/                    logo and the options page it was chosen from
specs/                        Spec Kit feature spec, plan, research, contracts, tasks
.github/workflows/            ci.yml (build and test), release.yml (tagged releases)
```

## Releases

Pushing a tag `vX.Y.Z` builds Grabby on a macOS runner, bundles and signs it, and publishes `Grabby.app.zip` with a checksum as a GitHub release. The release is signed ad hoc unless the repository has `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD` and `MACOS_SIGN_IDENTITY` secrets, in which case it is signed with that identity.

## Acknowledgements

- [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) by Noah Nuebling, whose source and macOS 27 investigation were the starting point for the Dock Swipe recipe.
- [SensibleSideButtons](https://sensible-side-buttons.archagon.net/) and the CalfTrail Touch reverse engineering it built on.

## License

[MIT](LICENSE).
