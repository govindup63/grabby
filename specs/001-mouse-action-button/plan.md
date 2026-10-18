# Implementation Plan: Mouse Action Button

**Branch**: `001-mouse-action-button` | **Date**: 2026-10-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-mouse-action-button/spec.md`

## Summary

Grabby is a menu bar app that swallows one spare mouse button and, while it is held,
turns mouse motion into desktop switching (Spaces) and Mission Control. Technically:
a `CGEventTap` on other-mouse button events selects and suppresses the action button;
a second tap, live only while the button is held, feeds raw deltas into a pure Swift
gesture state machine; the recognized gesture drives one of two output engines. The
Smooth engine posts synthetic Dock Swipe gestures as an `IOHIDEvent` attached to a
`CGEvent` via SkyLight's `SLEventSetIOHIDEvent`, which is the only recipe that works on
macOS 27. The Keyboard engine triggers the system's own symbolic hotkeys (Move Left a
Space 79, Move Right 81, Mission Control 32, App Expose 33, Show Desktop 36). Each
smooth gesture is verified by comparing the active Space before and after; a miss is
caught up by the Keyboard engine and two misses in a row make the fallback sticky for
the session. All gesture logic lives in a library with no AppKit dependency and is
written test-first with Swift Testing.

## Technical Context

**Language/Version**: Swift 6.4 (swiftlang-6.4.0.30.4), Swift 6 language mode

**Primary Dependencies**: AppKit (status item, event taps, `NSWorkspace`), SwiftUI
(Settings window), CoreGraphics (`CGEventTap`, `CGEventPost`,
`CGWarpMouseCursorPosition`), IOKit (`IOHIDEventCreate` and setters, exported but
undocumented), SkyLight (`SLEventSetIOHIDEvent`, `CGSGetSymbolicHotKeyValue`,
`CGSSetSymbolicHotKeyValue`, `CGSIsSymbolicHotKeyEnabled`, `CGSGetActiveSpace`,
`CGSCopyManagedDisplaySpaces`, all private), ServiceManagement (`SMAppService` for
launch at login). No third-party packages.

**Storage**: one JSON file, `~/Library/Application Support/Grabby/settings.json`

**Testing**: Swift Testing (`import Testing`) via `swift test`. XCTest is not available
(Command Line Tools only). The package must pass `-plugin-path` for the testing macros
and two `-rpath` entries so the test bundle loads; see research.md R1. Runtime
behaviour that cannot be unit tested is verified with quickstart.md and a
command-line probe.

**Target Platform**: macOS 27.0 (build 26A428) on Apple silicon. Deployment target
macOS 26 so the `@available(macOS 27)` guard is meaningful; older recipes are not
included.

**Project Type**: desktop app (menu bar agent) plus a pure library and a probe CLI

**Performance Goals**: idle CPU under 1 percent with no move tap enabled; during a
drag, at most one Dock Swipe "changed" event per 8 ms regardless of mouse report rate
(1000 Hz mouse); tap callback returns in well under the system's tap timeout.

**Constraints**: Accessibility permission required; no sandbox; no Xcode (build and
sign from the terminal with the one "Apple Development" identity in the keychain);
private API confined to one C target; every private call has a fallback; memory under
50 MB.

**Scale/Scope**: single user, one mouse, one settings pane, roughly 15 source files,
6 test files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan satisfies it | Status |
|---|---|---|
| I. Test-First (NON-NEGOTIABLE) | All gesture, scaling, coalescing, stepping, fallback and settings logic is in `GrabbyCore`, a target with no AppKit import, so every behaviour has a Swift Testing test written and seen failing before the code. `swift test` is proven to work on this machine (research R1). The app layer is thin glue around protocols the tests fake. | PASS |
| II. Verification Before Done | quickstart.md defines the runtime checklist on the real mouse, plus the `grabby-probe` CLI that posts one synthetic Dock Swipe and reports whether the active Space changed. Console logs are read via `log stream` with the app's subsystem. | PASS |
| III. Simplicity and Minimal Change | One process, no helper agent, no third-party dependencies, no per-app rules, no feature flags. The pre-macOS-27 Dock Swipe recipe is deliberately not ported. Two engines exist because the spec requires a fallback, not for generality. | PASS |
| Workflow: new dependencies need asking | None added. | PASS |
| Workflow: no README unless asked | None created. The AGENTS.md rule about restructuring the README file tree applies only if a README exists. | PASS |
| Quality gates: no secrets, no dead code | No secrets; private symbol declarations are limited to those used. | PASS |

No violations. Complexity Tracking left empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-mouse-action-button/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── grabby-core-api.md
│   ├── settings-schema.json
│   └── grabby-probe-cli.md
└── tasks.md             # Phase 2 output (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
Package.swift                      # SwiftPM manifest: 3 targets + 1 test target
Sources/
├── GrabbyCore/                    # pure Swift, no AppKit; all unit-tested
│   ├── GestureRecognizer.swift
│   ├── SwipeProgressScaler.swift
│   ├── EventCoalescer.swift
│   ├── EndPhaseDecider.swift
│   ├── DiscreteStepper.swift
│   ├── FallbackDecider.swift
│   ├── Settings.swift
│   ├── SettingsStore.swift        # JSON load/save with injected file access
│   ├── GestureController.swift    # wires recognizer -> engine via protocols
│   └── Protocols.swift            # GestureOutput, SystemActionRunner, PointerPin, Clock
├── GrabbyPrivate/                 # C target: the only place private API is declared
│   ├── include/GrabbyPrivate.h
│   └── GrabbyPrivate.c            # dlsym-based resolvers so a missing symbol is a nil, not a link error
├── GrabbyApp/                     # executable: menu bar app
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── StatusItemController.swift
│   ├── ButtonTap.swift
│   ├── MoveTap.swift
│   ├── DockSwipeEngine.swift
│   ├── HotkeyEngine.swift
│   ├── SpaceObserver.swift        # active Space id, Space count per display
│   ├── PointerPinner.swift
│   ├── Permissions.swift
│   ├── LearnButtonController.swift
│   ├── ConflictDetector.swift
│   ├── LaunchAtLogin.swift
│   ├── SettingsView.swift
│   └── Resources/Info.plist
└── GrabbyProbe/                   # executable: developer probe CLI
    └── main.swift
Tests/
└── GrabbyCoreTests/
    ├── GestureRecognizerTests.swift
    ├── SwipeProgressScalerTests.swift
    ├── EventCoalescerTests.swift
    ├── EndPhaseDeciderTests.swift
    ├── DiscreteStepperTests.swift
    ├── FallbackDeciderTests.swift
    ├── SettingsTests.swift
    └── GestureControllerTests.swift
scripts/
├── bundle.sh                      # builds release, assembles Grabby.app, codesigns
└── run-dev.sh                     # bundle + open, for the runtime checklist
```

**Structure Decision**: single SwiftPM package with a pure library (`GrabbyCore`), a
C shim target (`GrabbyPrivate`), the app executable (`GrabbyApp`) and a probe
executable (`GrabbyProbe`). SwiftPM cannot produce a `.app` bundle, so
`scripts/bundle.sh` wraps the built binary with an Info.plist (`LSUIElement`,
bundle id `com.pixelstwo.grabby`) and signs it with the Apple Development identity so
the Accessibility grant survives rebuilds.

## Phase 0: Research

See [research.md](research.md). All Technical Context items are resolved; there were
no NEEDS CLARIFICATION markers because the design document and the earlier research
session settled the approach. Research recorded the following decisions with
evidence gathered on this machine:

- R1: Swift Testing on Command Line Tools (verified green and red runs).
- R2: `SLEventSetIOHIDEvent` is the attach function; `CGEventSetHIDEvent` does not
  exist as a system symbol (verified with `dlsym`).
- R3: IOHIDEvent constants for Dock Swipe and Velocity (from IOKit headers mirrored in
  Mac Mouse Fix).
- R4: Symbolic hotkey triggering and restoration.
- R5: Event tap placement, permissions, re-enable and self-event tagging.
- R6: Pointer pinning.
- R7: Conflict detection for BetterMouse and Logitech G HUB.
- R8: App bundling and signing without Xcode.

## Phase 1: Design

- [data-model.md](data-model.md): Settings, Gesture, Engine state, Conflict, and the
  gesture state machine.
- [contracts/grabby-core-api.md](contracts/grabby-core-api.md): public API of
  `GrabbyCore` that the app and the tests program against.
- [contracts/settings-schema.json](contracts/settings-schema.json): the persisted
  settings file.
- [contracts/grabby-probe-cli.md](contracts/grabby-probe-cli.md): the probe command.
- [quickstart.md](quickstart.md): build, test, bundle, and the runtime checklist.

## Constitution Check (post-design)

Re-evaluated after Phase 1. The design adds no dependencies, no second process and no
abstraction beyond the four protocols needed to fake side effects in tests. Every
`GrabbyCore` type in the contract has a corresponding test file. PASS.

## Complexity Tracking

No violations to justify.
