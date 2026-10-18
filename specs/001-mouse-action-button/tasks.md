# Tasks: Mouse Action Button

**Input**: Design documents from `/specs/001-mouse-action-button/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Mandatory. The project constitution (Principle I) requires every test to be
written and observed failing before its implementation, and passing tests plus the
quickstart runtime checklist are the completion signal. Test tasks therefore precede
implementation tasks in every phase. The test command is `swift test`
(Swift Testing; flags live in Package.swift, see research.md R1).

**Organization**: Tasks are grouped by user story so each story is an independently
testable increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1 to US5)
- Include exact file paths in descriptions

## Path Conventions

Single SwiftPM package at the repository root (plan.md "Project Structure"):
`Sources/GrabbyCore`, `Sources/GrabbyPrivate`, `Sources/GrabbyApp`,
`Sources/GrabbyProbe`, `Tests/GrabbyCoreTests`, `scripts/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: a package that builds, a test target that runs red and green, and a
bundling script, before any feature code.

- [X] T001 Create `Package.swift` (swift-tools-version 6.0, platforms macOS 26) declaring targets `GrabbyCore` (library), `GrabbyPrivate` (C target, `Sources/GrabbyPrivate` with `include/`), `GrabbyApp` (executable, depends on GrabbyCore and GrabbyPrivate, links SkyLight via `linkerSettings: [.unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "SkyLight"])]` is NOT used; link only AppKit, CoreGraphics, IOKit, ServiceManagement and resolve private symbols with dlsym), `GrabbyProbe` (executable, depends on GrabbyCore and GrabbyPrivate), and test target `GrabbyCoreTests` with the three Swift Testing flags from research.md R1 (`-plugin-path .../host/plugins/testing`, rpath `.../Library/Developer/Frameworks`, rpath `.../Library/Developer/usr/lib`)
- [X] T002 Create the directory skeleton with placeholder sources so the package resolves: `Sources/GrabbyCore/Protocols.swift` (empty `import Foundation`), `Sources/GrabbyPrivate/include/GrabbyPrivate.h`, `Sources/GrabbyPrivate/GrabbyPrivate.c`, `Sources/GrabbyApp/main.swift`, `Sources/GrabbyProbe/main.swift`, `Tests/GrabbyCoreTests/SmokeTests.swift` containing one `@Test` that asserts `true`; run `swift build` and `swift test` and confirm the smoke test passes
- [X] T003 [P] Create `Sources/GrabbyApp/Resources/Info.plist` with `CFBundleIdentifier com.pixelstwo.grabby`, `CFBundleName Grabby`, `CFBundleExecutable Grabby`, `CFBundleShortVersionString 0.1.0`, `LSUIElement true`, `LSMinimumSystemVersion 26.0`, `NSPrincipalClass NSApplication`
- [X] T004 [P] Create `scripts/bundle.sh` (executable): `swift build -c release --product GrabbyApp`, assemble `build/Grabby.app/Contents/{MacOS/Grabby,Resources,Info.plist}`, `codesign --force --options runtime --sign "Apple Development: govindup63@gmail.com (Y9N4XD635T)" build/Grabby.app`, then print `codesign -dv` output; fail loudly if the identity is missing
- [X] T005 [P] Create `scripts/run-dev.sh` (executable): run `scripts/bundle.sh`, `pkill -x Grabby || true`, `open build/Grabby.app`, and print the `log stream` command from quickstart.md
- [X] T006 [P] Create `.gitignore` with `.build/`, `build/`, `*.xcodeproj`, `.DS_Store`

**Checkpoint**: `swift test` is green with the smoke test; `scripts/bundle.sh` produces a signed empty app that launches and exits.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the core types and protocols every story programs against, persisted
settings, private-symbol resolution, logging, and the event taps. No user story can
be exercised without these.

- [X] T007 Write `Tests/GrabbyCoreTests/SettingsTests.swift`: defaults match data-model.md (`actionButton nil`, `switchingStyle .keyboard`, `dragDownAction .appExpose`, `tapAction .missionControl`, `naturalDirection nil`, `pinPointer true`, `launchAtLogin false`, `schemaVersion 1`); JSON round-trip equality; `validated()` throws for `actionButton` 0 and 1 and for 32, accepts 2 and 31; decoding ignores an unknown key; decoding fills a missing key with its default; `SettingsStore.load()` returns defaults when `read` returns nil and when it returns garbage, and `save` writes bytes that `load` decodes back. Run `swift test --filter SettingsTests` and confirm it fails to compile or fails
- [X] T008 Implement `Sources/GrabbyCore/Protocols.swift` exactly as contracts/grabby-core-api.md: `Clock`, `GestureOutput`, `SpaceReader`, `PointerPin`, `UserNotifier`, plus `Axis`, `StepCommand`, `SwitchingStyle`, `DragDownAction`, `TapAction`, `Point`, `Size`
- [X] T009 Implement `Sources/GrabbyCore/Settings.swift` (`Settings`, `Settings.defaults`, `validated()`, `SettingsError.invalidButton`, custom `init(from:)` that applies defaults for missing keys) and `Sources/GrabbyCore/SettingsStore.swift` (`init(read:write:)`, `load()`, `save(_:)`) until T007 passes
- [X] T010 [P] Implement `Sources/GrabbyPrivate/include/GrabbyPrivate.h` and `Sources/GrabbyPrivate/GrabbyPrivate.c`: a `grabby_private_resolve(void)` that dlopens `/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight` and `/System/Library/Frameworks/IOKit.framework/IOKit` and fills a `struct grabby_private_api` of function pointers for `SLEventSetIOHIDEvent`, `IOHIDEventCreate`, `IOHIDEventSetIntegerValue`, `IOHIDEventSetFloatValue`, `IOHIDEventAppendEvent`, `CGSMainConnectionID`, `CGSGetActiveSpace`, `CGSCopyManagedDisplaySpaces`, `CGSGetSymbolicHotKeyValue`, `CGSSetSymbolicHotKeyValue`, `CGSIsSymbolicHotKeyEnabled`, `CGSSetSymbolicHotKeyEnabled`; a `grabby_private_all_present(const struct*)` helper; constants from research.md R3 (`GRABBY_HID_TYPE_DOCK_SWIPE 23`, `GRABBY_HID_TYPE_VELOCITY 9`, field ids, `GRABBY_FLAVOR_DOCK_PRIMARY 1`, phase bits, `GRABBY_PHASE_SHIFT 24`) and the symbolic hotkey ids (79, 81, 32, 33, 36) with the `CGSModifierFlags` masks (`kCGSNumericPadKeyMask 1<<21`, `kCGSFunctionKeyMask 1<<23`)
- [X] T011 [P] Create `Sources/GrabbyApp/Log.swift`: `os.Logger` instances under subsystem `com.pixelstwo.grabby` with categories `tap`, `gesture`, `engine`, `permission`, `settings`
- [X] T012 [P] Create `Sources/GrabbyApp/EventSource.swift`: one shared `CGEventSource(stateID: .hidSystemState)` with `userData = 0x47524142`, and `func isOwnEvent(_ e: CGEvent) -> Bool` comparing `kCGEventSourceUserData`
- [X] T013 Create `Sources/GrabbyApp/TapThread.swift`: a `Thread` subclass with its own `RunLoop` kept alive by a port, `start()` blocking until the run loop exists, and `perform(_ block:)` to run work on it
- [X] T014 Create `Sources/GrabbyApp/ButtonTap.swift`: `CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: otherMouseDown | otherMouseUp)` on the TapThread; callback ignores own events (T012), re-enables on `tapDisabledByTimeout`, reads `kCGMouseEventButtonNumber`, and when it equals `actionButton` returns `nil` and calls `onDown(location:)` / `onUp()`; `create()` returns `false` when `tapCreate` returns `nil` (no Accessibility); `setActionButton(_:)`, `enable()`, `disable()`
- [X] T015 Create `Sources/GrabbyApp/MoveTap.swift`: same location and options, mask `otherMouseDragged | mouseMoved`, created once, `enable()`/`disable()` only, callback ignores own events, reads `kCGMouseEventDeltaX/Y` as Double and calls `onMove(dx:dy:)`; optional `pinOrigin: CGPoint?` which, when set, calls `CGWarpMouseCursorPosition(origin)` after reading the delta (this is the PointerPin implementation surface; `CGEventSource.setLocalEventsSuppressionInterval(0)` on the shared source at creation)
- [X] T016 Create `Sources/GrabbyApp/Permissions.swift`: `static func hasAccess() -> Bool` by attempting a throwaway `.defaultTap` creation on `otherMouseDown` and releasing it; `func openAccessibilityPane()` opening `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`; `func startPolling(interval: TimeInterval, onChange: (Bool) -> Void)` with a 1 second timer while access is missing and 5 seconds while present (research.md R5)
- [X] T017 Create `Sources/GrabbyApp/main.swift` and `Sources/GrabbyApp/AppDelegate.swift`: `NSApplication` with `setActivationPolicy(.accessory)`, load settings via `SettingsStore` reading/writing `~/Library/Application Support/Grabby/settings.json` (create directory; rename undecodable file to `settings.json.broken`), resolve `grabby_private_resolve()` and log which symbols are missing, start TapThread, create ButtonTap and MoveTap only when `Permissions.hasAccess()`, otherwise log `permission missing` (UI arrives in US3)
- [X] T018 Create `Sources/GrabbyApp/StatusItemController.swift`: `NSStatusItem` with an SF Symbol `cursorarrow.motionlines`, menu items `Settings...` (opens the settings window, implemented in US2; stub opens nothing yet), a disabled status line item, and `Quit Grabby`

**Checkpoint**: `swift test` green (Settings tests). `scripts/run-dev.sh` shows the menu bar icon; with Accessibility granted to the dev-signed app, `log stream` shows other-button clicks reaching the ButtonTap callback and passing through because `actionButton` is nil. Quit works.

---

## Phase 3: User Story 1 - Switch desktops by holding a button and dragging (Priority: P1) 🎯 MVP

**Goal**: hold the action button and drag horizontally to move between Spaces,
following the pointer in Smooth style; drag up for Mission Control; pointer pinned
during the drag; left and right clicks untouched.

**Independent Test**: with `settings.json` hand-edited to `"actionButton": 4` and
`"switchingStyle": "smooth"` (contracts/settings-schema.json), quickstart.md steps
11, 12, 13, 17, 18 pass on the real mouse, and `swift run grabby-probe --repeat 6`
exits 0. Keyboard style for this story is exercised through US4.

### Tests for User Story 1 (write first, see them fail)

- [X] T019 [P] [US1] Write `Tests/GrabbyCoreTests/GestureRecognizerTests.swift` from data-model.md "State machine": `buttonDown` returns `[]`; moves summing under 7 points then `buttonUp` returns `[.tap]`; a move making `max(abs(x),abs(y)) > 7` returns `[.dragBegan(axis)]` with the larger component's axis and a tie going horizontal; after lock, a move returns `[.dragChanged(d)]` with only the locked axis component; `buttonUp` while dragging returns `[.dragEnded]`; `cancel()` while dragging returns `[.dragCancelled]` and while idle returns `[]`; `distance` is the signed sum along the axis
- [X] T020 [P] [US1] Write `Tests/GrabbyCoreTests/SwipeProgressScalerTests.swift`: for a 1512 wide screen and 2, 3 and 5 Spaces, a drag of `-(1512 + 63)` points yields horizontal progress of exactly `offsetForOneSpace` (2.0, 1.5, 1.25) within 1e-9; one Space uses 2.0; `naturalDirection true` flips the sign; vertical progress of a `screen.height` drag is 1.0
- [X] T021 [P] [US1] Write `Tests/GrabbyCoreTests/EventCoalescerTests.swift` with a fake `Clock`: `began(progress:)` returns the progress and sets `originOffset`; 19 `changed` calls within 8 ms return nil for all but the first (first call after `began` is sent immediately) and the next call after 8 ms returns the summed delta; no motion is lost: `flushForEnd()` equals the sum of all deltas; `lastDelta` is the most recent non-zero delta; a zero delta returns nil and does not update `lastDelta`
- [X] T022 [P] [US1] Write `Tests/GrabbyCoreTests/EndPhaseDeciderTests.swift`: same sign gives `.ended`, opposite sign gives `.cancelled`, `lastDelta 0` gives `.ended`; `exitSpeed(lastDelta: 0.02) == 2.0`
- [X] T023 [US1] Write `Tests/GrabbyCoreTests/GestureControllerTests.swift` (smooth and vertical cases; keyboard cases are added in US4) with fakes for `GestureOutput`, `SpaceReader`, `PointerPin`, `UserNotifier`, `Clock`: a tap calls `output.perform(.missionControl)` for the default tap action, nothing for `.none`, `.appExpose`/`.showDesktop` accordingly, and sets `lastTapWasPassThrough` for `.passThrough`; a horizontal drag in smooth style produces exactly one `dockSwipeBegan(.horizontal, _)`, then coalesced `dockSwipeChanged` calls, then one `dockSwipeEnded` (or `dockSwipeCancelled` when the last delta reverses); `pointer.pin(at: origin)` is called on began and `unpin()` on end when `pinPointer` is true and never when false; a vertical drag up produces `dockSwipeBegan(.vertical, _)` in smooth style; a vertical drag down with `dragDownAction .showDesktop` calls `perform(.showDesktop)` and no dock swipe calls even in smooth style; with `dragDownAction .none` a down drag produces nothing; `cancelGesture()` mid-drag produces `dockSwipeCancelled` and `unpin()`; `smoothAvailable false` with style smooth routes a vertical up drag to `perform(.missionControl)`. Confirm the whole file fails

### Implementation for User Story 1

- [X] T024 [P] [US1] Implement `Sources/GrabbyCore/GestureRecognizer.swift` until T019 passes (threshold constant 7, `isDragging`, `axis`, `distance`)
- [X] T025 [P] [US1] Implement `Sources/GrabbyCore/SwipeProgressScaler.swift` until T020 passes (`spaceSeparatorWidth 63`, horizontal `-dx * scale`, natural direction negates)
- [X] T026 [P] [US1] Implement `Sources/GrabbyCore/EventCoalescer.swift` until T021 passes (`interval 8 ms`, accumulate `pendingDelta`, `originOffset`, `lastDelta`)
- [X] T027 [P] [US1] Implement `Sources/GrabbyCore/EndPhaseDecider.swift` until T022 passes
- [X] T028 [US1] Implement `Sources/GrabbyCore/GestureController.swift` until T023 passes: owns `GestureRecognizer`, `SwipeProgressScaler` (built at began from `spaces.screenSize()` and `spaces.spaceCount(onDisplayUnderPointer: true)`), `EventCoalescer`, effective-engine rule `style == .smooth && smoothAvailable && !stickyFallback`, Show Desktop always via `perform`, records `spaceBefore = spaces.activeSpace()` at began for US4; leave `verifySmoothGesture` as a stub that stores the value until US4
- [ ] T029 [P] [US1] Create `Sources/GrabbyApp/SpaceObserver.swift` implementing `SpaceReader`: `activeSpace()` via `CGSGetActiveSpace(CGSMainConnectionID())`; `spaceCount(onDisplayUnderPointer:)` via `CGSCopyManagedDisplaySpaces` matching the `Display Identifier` to the UUID of `NSScreen` under `NSEvent.mouseLocation` (fallback 1 when any symbol is missing); `screenSize()` from that screen's frame
- [ ] T030 [P] [US1] Create `Sources/GrabbyApp/HotkeyEngine.swift`: `perform(_ step: StepCommand)` mapping to ids 79, 81, 32, 33, 36; read binding with `CGSGetSymbolicHotKeyValue`; if enabled and reachable, post key down and up with `CGEventCreateKeyboardEvent` on the shared source with flags set exactly to the binding's modifiers (all others cleared); otherwise enable, rebind to virtual key `id + 400` with Fn plus Numeric Pad flags, post, and restore binding and enabled state in `defer`; log the binding before and after at debug level
- [ ] T031 [US1] Create `Sources/GrabbyApp/DockSwipeEngine.swift`: `postDockSwipe(axis:phase:progress:exitSpeed:)` building the IOHIDEvent per research.md R3 (type 23, options `phase << 24`, Motion 1 or 2, Flavor 1, Progress; Velocity child with X = Y = exitSpeed, Z = 0 on ended/cancelled), wrapping in `CGEventCreate(nil)` with type 30 via `SLEventSetIOHIDEvent`, posting at `kCGSessionEventTap`; on ended/cancelled schedule resends at 200 ms and 500 ms, cancelled by the next began; return `false` (hard error) when any symbol is missing; honour `GRABBY_FAKE_SMOOTH_FAILURE=1` by posting nothing and returning `true`
- [ ] T032 [US1] Create `Sources/GrabbyApp/GestureOutputAdapter.swift` implementing `GestureOutput` by delegating dock swipe calls to `DockSwipeEngine` and `perform` to `HotkeyEngine`, reporting a hard error back to the controller through a closure
- [ ] T033 [US1] Wire it in `Sources/GrabbyApp/AppDelegate.swift`: construct `GestureController` with `SpaceObserver`, the adapter, `MoveTap` as `PointerPin` (set/clear `pinOrigin`), a `UserNotifier` stub, and a monotonic `Clock`; `ButtonTap.onDown` enables MoveTap and calls `actionButtonDown(at:)`, `onUp` calls `actionButtonUp()` and disables MoveTap; `MoveTap.onMove` calls `pointerMoved`; `applicationWillTerminate` calls `cancelGesture()`; log every gesture event at debug level
- [ ] T034 [US1] Implement `Sources/GrabbyProbe/main.swift` per contracts/grabby-probe-cli.md: `--symbols`, `--direction`, `--repeat`, `--json`, `--hotkey`, exit codes 0/1/2/64, sharing `DockSwipeEngine`, `HotkeyEngine` and `SpaceObserver` by moving those three files into a new internal target `GrabbyEngines` (update `Package.swift` so GrabbyApp and GrabbyProbe both depend on it)
- [ ] T035 [US1] Run `swift test`, then `swift run grabby-probe --symbols` and `swift run grabby-probe --repeat 6`, then quickstart.md steps 11, 12, 13, 17, 18 with `settings.json` hand-edited; record results in the commit message

**Checkpoint**: desktops slide under the pointer with the side button held; Mission Control opens on drag up; probe exits 0.

---

## Phase 4: User Story 2 - Choose the action button and what a tap does (Priority: P1)

**Goal**: a Settings window with the learn step, tap action, drag-down action,
natural direction and pointer pinning controls, all persisted.

**Independent Test**: quickstart.md steps 3, 4, 5, 15, 16; relaunch keeps the
settings.

### Tests for User Story 2 (write first, see them fail)

- [ ] T036 [P] [US2] Write `Tests/GrabbyCoreTests/LearnButtonTests.swift` for a pure `LearnButtonSession` state machine: `start(at:)`; `buttonPressed(number:at:)` returns `.rejected(reason:)` for 0 and 1 and `.learned(number)` for 2...31; `tick(now:)` returns `.timedOut` once 10 seconds have elapsed with no press and `.waiting` before; after `.learned` further presses return `.finished`
- [ ] T037 [US2] Extend `Tests/GrabbyCoreTests/GestureControllerTests.swift`: changing `settings.tapAction` at runtime changes the next tap's `perform`; `lastTapWasPassThrough` resets to false on the next button down; changing `settings.actionButton` has no effect inside the controller (it is the tap's concern) but is accepted

### Implementation for User Story 2

- [ ] T038 [US2] Implement `Sources/GrabbyCore/LearnButtonSession.swift` until T036 passes (timeout constant 10 s)
- [ ] T039 [US2] Update `Sources/GrabbyCore/GestureController.swift` until T037 passes
- [ ] T040 [US2] Create `Sources/GrabbyApp/LearnButtonController.swift`: on start, disable `ButtonTap` swallowing, create a listen-only tap (`options: .listenOnly`) on `otherMouseDown | leftMouseDown | rightMouseDown`, feed presses to `LearnButtonSession`, a 0.5 s timer feeds `tick`; on `.learned` save `actionButton`, re-enable swallowing with the new button; on `.rejected` show the reason inline; on `.timedOut` show "Nothing arrived. Your mouse software may have remapped this button."; always tear down the listen tap
- [ ] T041 [US2] Create `Sources/GrabbyApp/SettingsView.swift` (SwiftUI) in the order from the design document: status line; action button with "Change..." (binds to LearnButtonController state); Style picker (Smooth / Keyboard shortcut) and Natural direction toggle; drag left/right (fixed text), drag up (fixed text), drag down picker (App Expose / Show Desktop / Nothing); tap picker (Mission Control / App Expose / Show Desktop / Nothing / Pass click through); "Keep pointer in place while dragging" toggle; "Launch at login" toggle (wired in US5); conflicts box placeholder (wired in US3). Every control writes through a `SettingsModel` `ObservableObject` that validates and saves via `SettingsStore` and pushes the new `Settings` into `GestureController`
- [ ] T042 [US2] Create `Sources/GrabbyApp/SettingsWindowController.swift` hosting `SettingsView` in an `NSWindow` (`NSHostingController`), opened from the status item menu, `NSApp.activate` on open, single instance
- [ ] T043 [US2] Implement pass-through in `Sources/GrabbyApp/AppDelegate.swift`: when `controller.lastTapWasPassThrough` is true after `actionButtonUp`, post `otherMouseDown` then `otherMouseUp` for the action button at the current location on the shared tagged source (ButtonTap ignores them via `isOwnEvent`)
- [ ] T044 [US2] Apply `naturalDirection nil` at launch in `AppDelegate.swift`: read `com.apple.swipescrolldirection` from `UserDefaults.standard` (default true) and pass the resolved Bool to the controller without writing it back to settings
- [ ] T045 [US2] Run `swift test`, then quickstart.md steps 3, 4, 5, 15, 16 and a relaunch check; record results

**Checkpoint**: the button is chosen by pressing it; tap and drag-down actions configurable; settings survive relaunch.

---

## Phase 5: User Story 3 - Grant permission and get told about conflicts (Priority: P2)

**Goal**: onboarding when Accessibility is missing, live detection of grant and
revocation, and conflict notices for BetterMouse and Logitech G HUB.

**Independent Test**: quickstart.md steps 1, 2, 20, 23.

### Tests for User Story 3 (write first, see them fail)

- [ ] T046 [P] [US3] Write `Tests/GrabbyCoreTests/ConflictAdviceTests.swift` for a pure `ConflictAdvice.make(tools: [ConflictTool], actionButton: Int?) -> [Conflict]`: BetterMouse yields advice containing "BetterMouse" and "button 4" when the button is 4; G HUB yields advice naming "Logitech G HUB" and the default-assignment instruction; Options+ likewise; nil button yields advice without a button number; empty tools yields []

### Implementation for User Story 3

- [ ] T047 [US3] Implement `Sources/GrabbyCore/Conflict.swift` (`ConflictTool`, `Conflict`, `ConflictAdvice`) until T046 passes
- [ ] T048 [US3] Create `Sources/GrabbyApp/ConflictDetector.swift`: map `NSWorkspace.shared.runningApplications` to `ConflictTool` by bundle id prefix `com.logitech` (distinguish G HUB `lghub` from Options+ by bundle id or name) and by bundle id or localized name containing "BetterMouse"; called when the settings window appears and every 5 s while it is open
- [ ] T049 [US3] Create `Sources/GrabbyApp/OnboardingView.swift` (SwiftUI): explains Accessibility access, "Open System Settings" button calling `Permissions.openAccessibilityPane()`, and a line "Grabby will start working as soon as access is granted"
- [ ] T050 [US3] Update `Sources/GrabbyApp/AppDelegate.swift`: on launch without access show the onboarding window and start `Permissions.startPolling`; on grant create the taps, close onboarding, update the status line to "Grabby is working"; on revocation disable both taps, call `controller.cancelGesture()`, set the status line to "Needs Accessibility access" and reopen onboarding; status item menu status line reflects the state
- [ ] T051 [US3] Wire the conflicts box in `Sources/GrabbyApp/SettingsView.swift` to `ConflictDetector` output, hidden when empty
- [ ] T052 [US3] Run `swift test`, then quickstart.md steps 1, 2, 20, 23; record results

**Checkpoint**: first launch guides the user to grant access and the app starts working without relaunch; revocation is safe; conflicts are named.

---

## Phase 6: User Story 4 - Keyboard style and automatic fallback (Priority: P2)

**Goal**: Keyboard switching style with discrete steps, per-gesture verification of
smooth gestures, catch-up steps, sticky fallback after two failures with a one-time
notice.

**Independent Test**: quickstart.md steps 6, 7, 8, 9, 10, 14.

### Tests for User Story 4 (write first, see them fail)

- [X] T053 [P] [US4] Write `Tests/GrabbyCoreTests/DiscreteStepperTests.swift` from data-model.md "Discrete stepping": horizontal, deltas summing to 59 fire nothing, reaching 60 fires `[.moveSpaceRight]` once (positive distance is right), reaching 260 fires a second, 460 a third; dragging back from 100 to 0 fires nothing and does not retract; crossing to -60 after a right step fires `[.moveSpaceLeft]` (count reset at the origin); vertical up fires `[.missionControl]` exactly once at 60 and nothing after; vertical down fires the configured action once (`.appExpose`, `.showDesktop`) and nothing for `.none`
- [ ] T054 [P] [US4] Write `Tests/GrabbyCoreTests/FallbackDeciderTests.swift` from data-model.md "Fallback observation": horizontal distance 80, Space unchanged, failures 0 gives `catchUpStep .moveSpaceRight`, `failureCount 1`, `becameSticky false`; same with failures 1 gives `becameSticky true`; Space changed gives nil step and `failureCount 0`; distance 40 unchanged gives nil step and `failureCount 0`; `hardError true` gives a catch-up step and increments; vertical distance 80 with `hardError false` is a success (verification by API error only); negative distance gives `.moveSpaceLeft`
- [ ] T055 [US4] Extend `Tests/GrabbyCoreTests/GestureControllerTests.swift`: keyboard style horizontal drag calls `perform(.moveSpaceRight)` at 60 and 260 and no dock swipe calls; smooth style then `verifySmoothGesture(spaceAfter: sameAsBefore)` after an 80 point drag calls `perform(.moveSpaceRight)`; after a second such failure `stickyFallback` is true and `notifier.showFallbackNotice()` was called exactly once; the next drag emits no dock swipe calls; a hard error reported mid-drag produces `dockSwipeCancelled` then `perform` of the catch-up step; a verified success resets so two non-consecutive failures do not go sticky

### Implementation for User Story 4

- [X] T056 [P] [US4] Implement `Sources/GrabbyCore/DiscreteStepper.swift` until T053 passes (`firstStep 60`, `nextStep 200`)
- [ ] T057 [P] [US4] Implement `Sources/GrabbyCore/FallbackDecider.swift` until T054 passes (`stickyAfter 2`)
- [ ] T058 [US4] Update `Sources/GrabbyCore/GestureController.swift` until T055 passes: keyboard path through `DiscreteStepper`; `verifySmoothGesture` runs `FallbackDecider`, performs the catch-up step, updates `consecutiveFailures`, sets `stickyFallback`, calls `notifier.showFallbackNotice()` once; `reportHardError()` entry point used by the adapter
- [ ] T059 [US4] Update `Sources/GrabbyApp/AppDelegate.swift`: after a smooth gesture ends, schedule `controller.verifySmoothGesture(spaceAfter: spaces.activeSpace())` 400 ms later on the main queue; implement `UserNotifier` with a status item menu line "Smooth switching failed, using keyboard shortcuts until relaunch" plus an `NSUserNotification`-free approach: a transient `NSAlert`-less menu bar title change for 5 s (no notification permission required)
- [ ] T060 [US4] Run `swift test`, then quickstart.md steps 6, 7, 8, 9, 10 in Keyboard style and step 14 with `GRABBY_FAKE_SMOOTH_FAILURE=1`; record results
- [ ] T061 [US4] If `swift run grabby-probe --repeat 6` exits 0 on this machine, flip `Settings.defaults.switchingStyle` to `.smooth` in `Sources/GrabbyCore/Settings.swift`, update the expectation in `Tests/GrabbyCoreTests/SettingsTests.swift` first (see it fail), then the default, and update `contracts/settings-schema.json` `default` to `"smooth"`

**Checkpoint**: both styles work; a dead smooth path never leaves a dead button.

---

## Phase 7: User Story 5 - Always on, out of the way (Priority: P3)

**Goal**: launch at login and verified idle cost.

**Independent Test**: quickstart.md steps 21, 22.

- [ ] T062 [US5] Create `Sources/GrabbyApp/LaunchAtLogin.swift` wrapping `SMAppService.mainApp`: `isEnabled`, `setEnabled(_:) throws`, and a `status` string for the UI; log and surface the error when the app is not running from a signed bundle (SwiftPM `swift run` case)
- [ ] T063 [US5] Wire the toggle in `Sources/GrabbyApp/SettingsView.swift` to `LaunchAtLogin`, mirror the result into `settings.launchAtLogin`, and show the error text inline when enabling fails
- [ ] T064 [US5] Measure idle cost per quickstart.md step 21 with the bundled release build; if CPU exceeds 1 percent, confirm `MoveTap` is disabled at idle (`CGEventTapIsEnabled`) and that `ButtonTap`'s mask excludes left and right; record the Activity Monitor numbers
- [ ] T065 [US5] Run quickstart.md step 22 (log out and in); record the result

**Checkpoint**: all five stories pass their independent tests.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T066 [P] Add `Tests/GrabbyCoreTests/SettingsStoreFileTests.swift` covering the app's real read/write closures factored into `GrabbyCore` as `SettingsStore.fileBacked(url:)` using a temporary directory: creates the directory, writes, reads back, renames an undecodable file to `settings.json.broken`
- [ ] T067 [P] Remove `Tests/GrabbyCoreTests/SmokeTests.swift` and any placeholder left from T002
- [ ] T068 Review every file in `Sources/GrabbyApp` and `Sources/GrabbyEngines` for private API use outside `GrabbyPrivate` symbol resolution (grep for `SLEvent`, `CGS`, `IOHIDEvent` and `dlsym`); move any stray declaration into `Sources/GrabbyPrivate`
- [ ] T069 Run the full quickstart.md checklist (steps 1 to 23) on the bundled release build and record the outcome of every step in `specs/001-mouse-action-button/quickstart-results.md`
- [ ] T070 Initialize the git repository if the user wants history (`git init`, first signed commit of the package and specs); the user's global rules require `git commit -s` and no AI attribution lines

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup; blocks all stories
- **US1 (Phase 3)**: depends on Foundational
- **US2 (Phase 4)**: depends on Foundational; uses `GestureController` from US1 for tap wiring, but the learn step and settings window can be built against the US1 contract in parallel
- **US3 (Phase 5)**: depends on Foundational only
- **US4 (Phase 6)**: depends on US1 (extends `GestureController` and uses both engines)
- **US5 (Phase 7)**: depends on US2 (settings window toggle)
- **Polish (Phase 8)**: depends on all stories

### Within Each Story

- Test tasks first, run them, see them fail, then implementation until green
- GrabbyCore before GrabbyApp
- Engines before wiring in `AppDelegate.swift`
- Runtime checklist steps last

### Parallel Opportunities

- Phase 1: T003, T004, T005, T006 after T001 and T002
- Phase 2: T010, T011, T012 while T007 to T009 proceed
- US1: T019 to T022 together; then T024 to T027 together; T029 and T030 together while T028 proceeds
- US2 and US3 can be built by two people at once after Foundational
- US4: T053 and T054 together; T056 and T057 together
- Polish: T066 and T067 together

---

## Parallel Example: User Story 1

```text
# Write all pure-logic tests together, run swift test, watch them fail:
Task: "GestureRecognizerTests.swift"
Task: "SwipeProgressScalerTests.swift"
Task: "EventCoalescerTests.swift"
Task: "EndPhaseDeciderTests.swift"

# Implement the four modules together until green:
Task: "GestureRecognizer.swift"
Task: "SwipeProgressScaler.swift"
Task: "EventCoalescer.swift"
Task: "EndPhaseDecider.swift"

# App engines together while GestureController is written:
Task: "SpaceObserver.swift"
Task: "HotkeyEngine.swift"
```

---

## Implementation Strategy

### MVP First (Setup + Foundational + US1)

1. Phase 1 and Phase 2: a signed menu bar app with taps and persisted settings
2. Phase 3: hold-and-drag desktop switching with a hand-edited settings file
3. Stop and validate with the probe and quickstart steps 11 to 13, 17, 18

### Incremental Delivery

1. US2 adds the Settings window and learn step: the app is usable without editing JSON
2. US3 adds onboarding and conflicts: first-run experience
3. US4 adds Keyboard style and the fallback: the button can never go dead
4. US5 adds launch at login
5. Polish and the full checklist

---

## Notes

- Every GrabbyCore task pairs with a test task that must be seen failing first
  (constitution Principle I). The app layer is verified by quickstart.md steps
  (Principle II); each story's last task records those results.
- No new dependencies anywhere. If one seems needed, ask first.
- Private API: declared and resolved only in `Sources/GrabbyPrivate`. Every call
  site handles a nil function pointer by taking the keyboard path.
- Commit after each green test run with `git commit -s`; no AI attribution lines.
