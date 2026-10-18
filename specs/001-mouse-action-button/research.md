# Research: Mouse Action Button

Date: 2026-10-18. Everything marked "verified" was run on the target machine
(macOS 27.0 build 26A428, Swift 6.4, Command Line Tools only).

## R1. Unit test runner without Xcode

**Decision**: Swift Testing (`import Testing`, `@Test`, `#expect`) run with
`swift test`. The package passes three extra flags on the test target through
`unsafeFlags`, which SwiftPM allows for root packages:

```swift
swiftSettings: [.unsafeFlags(["-plugin-path",
  "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])],
linkerSettings: [.unsafeFlags([
  "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
  "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"])]
```

**Rationale**: XCTest.framework is not shipped with Command Line Tools (verified: not
in the SDK, not under the CLT tree). Swift Testing is shipped, but the default
toolchain does not pass its macro plugin path or the runtime search paths, so a bare
`swift test` fails with "plugin for module 'TestingMacros' not found" and then with
"Library not loaded: @rpath/Testing.framework" and "@rpath/lib_TestingInterop.dylib".
With the three flags, a probe package ran one passing test and one deliberately
failing test correctly (verified). The constitution's red-green cycle is therefore
possible on this machine.

**Alternatives considered**: installing Xcode (user's call, not needed); a hand-rolled
executable test runner (loses `swift test` integration and assertion reporting).

Paths are absolute to the CLT install. If the toolchain moves, the flags move with it;
`scripts/test.sh` is not needed because the flags live in Package.swift.

## R2. Attaching the Dock Swipe IOHIDEvent to a CGEvent on macOS 27

**Decision**: build an `IOHIDEvent` of type DockSwipe with the IOKit C functions
(`IOHIDEventCreate`, `IOHIDEventSetIntegerValue`, `IOHIDEventSetFloatValue`,
`IOHIDEventAppendEvent`), create a `CGEvent` with `CGEventCreate(nil)`, set its type
to 30, and call SkyLight's `SLEventSetIOHIDEvent(cgEvent, hidEvent)`. Post with
`CGEventPost(kCGSessionEventTap, event)`.

**Rationale**: Mac Mouse Fix's exploration file (Tests/FixDockSwipes.m) states that on
macOS 27 the old `CGEvent` integer fields are ignored, that "CG-variant
(CGEventSetIOHIDEvent) doesn't work", and that `SLEventSetIOHIDEvent` from SkyLight is
what works. Their shipping `CGEventSetHIDEvent` is their own function that pokes a
pointer at offset 0x18 then 0xd0 inside the opaque CGEvent; it is not a system
symbol. Verified with `dlsym` on this machine:

| Symbol | Present in |
|---|---|
| `SLEventSetIOHIDEvent` | SkyLight |
| `CGEventSetHIDEvent` | nowhere (Mac Mouse Fix's own) |
| `IOHIDEventCreate`, `IOHIDEventSetIntegerValue`, `IOHIDEventSetFloatValue`, `IOHIDEventSetDoubleValue`, `IOHIDEventAppendEvent` | IOKit |
| `CGSGetActiveSpace`, `CGSCopyManagedDisplaySpaces`, `CGSMainConnectionID` | CoreGraphics, SkyLight |
| `CGSGetSymbolicHotKeyValue`, `CGSSetSymbolicHotKeyValue`, `CGSIsSymbolicHotKeyEnabled`, `CGSSetSymbolicHotKeyEnabled` | CoreGraphics, SkyLight |
| `CGEventGetSendingDevice` | nowhere (not needed; device filtering is out of scope) |

All private symbols are resolved at runtime with `dlsym` inside `GrabbyPrivate`, so a
missing symbol on a future macOS is a `nil` function pointer that routes to the
Keyboard engine, never a launch failure.

**Alternatives considered**: the pre-27 `CGEventSetIntegerValueField` recipe (dead on
27, measured 0 of 6 by Mac Mouse Fix PR #2023); Mac Mouse Fix's memory-offset poke
(works but depends on struct layout; SkyLight's function is the supported-by-them
path).

## R3. Dock Swipe event contents

**Decision**: constants, from IOKit's `IOHIDEventTypes.h` and `IOHIDEventFieldDefs.h`
as mirrored in Mac Mouse Fix:

| Item | Value |
|---|---|
| `kIOHIDEventTypeDockSwipe` | 23 |
| `kIOHIDEventTypeVelocity` | 9 |
| `IOHIDEventFieldBase(type)` | `type << 16` |
| `kIOHIDEventFieldDockSwipeMotion` | `(23 << 16) \| 1` |
| `kIOHIDEventFieldDockSwipeProgress` | `(23 << 16) \| 2` |
| `kIOHIDEventFieldDockSwipeFlavor` | `(23 << 16) \| 5` |
| `kIOHIDEventFieldVelocityX/Y/Z` | `(9 << 16) \| 0/1/2` |
| `kIOHIDGestureFlavorDockPrimary` | 1 |
| Motion: horizontal / vertical / pinch | 1 / 2 / 3 |
| Phase bits: began / changed / ended / cancelled | 1 / 2 / 4 / 8 |
| `kIOHIDEventEventOptionPhaseShift` | 24 (phase goes in the event options as `phase << 24`) |

Per event: create with type 23, timestamp 0, sender 0; set options to `phase << 24`;
set Motion, Flavor = 1, Progress = accumulated origin offset (sign flipped when
natural direction is on, because the macOS 27 path flips it itself). On ended or
cancelled, append a child Velocity event with X = Y = lastDelta * 100, Z = 0.

Progress scaling (Mac Mouse Fix, tuned so one screen width is one Space):
`offsetForOneSpace = spaces <= 1 ? 2 : 1 + 1/(spaces - 1)`;
`horizontalScale = offsetForOneSpace / (screenWidth + 63)`;
`verticalScale = 1 / screenHeight`. Space count per display comes from
`CGSCopyManagedDisplaySpaces`, matching the display's UUID.

Timing: coalesce "changed" to one per 8 ms (Mac Mouse Fix PR #2023 measured a 1000 Hz
mouse at up to 19 events per 8 ms frame and visible stutter; after coalescing, mean
1.09 per frame and smooth). Resend the end event after 200 ms and 500 ms to clear the
occasional stuck transition. Ended becomes cancelled when the last delta's sign
differs from the accumulated offset's sign.

## R4. Triggering Mission Control and Space moves without the gesture

**Decision**: symbolic hotkeys through SkyLight, the Mac Mouse Fix approach. For a
hotkey id (79 left, 81 right, 32 Mission Control, 33 App Expose, 36 Show Desktop):
read the current binding with `CGSGetSymbolicHotKeyValue`; if the hotkey is enabled
and its virtual key code is reachable, post that key down and up with
`CGEventCreateKeyboardEvent` and the binding's modifier flags, with all other
modifier flags explicitly cleared. If it is disabled or unreachable, enable it,
rebind it to an out-of-reach virtual key code (id + 400) with Fn plus Numeric Pad
flags, post, then restore the original binding and enabled state in a `defer`.

**Rationale**: posting literal Control+Arrow only works at the default shortcuts and
leaks the user's currently held modifiers (Ian Ynda-Hummel's post documents a click
becoming a Control-click this way). Reading the binding works whatever the user set.
Restoration satisfies the spec requirement that shortcut settings are never left
modified. On this machine all three hotkeys are at defaults (verified: not present in
`com.apple.symbolichotkeys`), so the rebind branch is rarely taken but must exist.

**Alternatives considered**: `CGSSpace` private functions to switch Space directly
(no animation, requires killing the Dock in some implementations, rejected);
AppleScript System Events (slow, needs Automation permission, rejected).

## R5. Event taps, permissions, self-events

**Decision**:

- Button tap: `CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
  options: .defaultTap, eventsOfInterest: otherMouseDown | otherMouseUp)`. Callback
  reads `kCGMouseEventButtonNumber`; if it equals the configured button, returns
  `nil` (swallowed) and notifies the controller; otherwise returns the event. Left
  (0) and right (1) are never in the mask.
- Move tap: same location and options, mask `otherMouseDragged | mouseMoved`,
  created once and enabled only between action-button down and up. Reads
  `kCGMouseEventDeltaX/Y`. Mac Mouse Fix's own measurement: a do-nothing tap over
  all events costs about 9 percent CPU while wiggling a 1000 Hz mouse, which is why
  the move tap is off at idle.
- Both taps run on a dedicated thread with its own run loop so UI work cannot stall
  the callback. On `tapDisabledByTimeout` the callback re-enables the tap; on
  `tapDisabledByUserInput` it does not.
- Self events: all posted events use one `CGEventSource` with
  `userData = 0x47524142` ("GRAB"); both taps return any event carrying that value
  untouched.
- Permission: a `.defaultTap` and `CGEventPost` need the Accessibility grant.
  `CGEvent.tapCreate` returns `nil` without it, which is the detection used; an Apple
  engineer in Developer Forums thread 735204 confirms `AXIsProcessTrusted` can stay
  true after revocation. Onboarding opens
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
  and retries tap creation every second. Revocation is detected by a 5 second timer
  that attempts to create a throwaway `.defaultTap`; on failure the live taps are
  disabled and the status line changes. BetterMouse's docs and Mac Mouse Fix both
  confirm Input Monitoring is not needed for mouse-only taps.

## R6. Pointer pinning

**Decision**: while a drag is active and pinning is on, the move tap callback calls
`CGWarpMouseCursorPosition(origin)` after reading the delta. Mac Mouse Fix does the
same and sets the event suppression interval to zero around it so warping does not
pause input. On drag end the pointer is left at the origin. No puppet cursor.

## R7. Conflict detection

**Decision**: when the Settings window appears, check
`NSWorkspace.shared.runningApplications` for bundle identifiers starting with
`com.logitech` (G HUB agent and Options+), and for a localized name or bundle id
containing "BetterMouse". Show a notice naming the tool and the chosen button number.
On this machine BetterMouse 1.6 is installed and not running; the G HUB agent
`lghub_agent` is running (verified with `pgrep`).

## R8. Building, bundling and signing without Xcode

**Decision**: `swift build -c release --product GrabbyApp`, then `scripts/bundle.sh`
creates `build/Grabby.app/Contents/{MacOS,Resources}`, copies the binary and
`Info.plist` (`CFBundleIdentifier com.pixelstwo.grabby`, `LSUIElement true`,
`LSMinimumSystemVersion 26.0`), and runs
`codesign --force --sign "Apple Development: govindup63@gmail.com (Y9N4XD635T)"
--options runtime --entitlements none build/Grabby.app`. `SMAppService.mainApp` handles
launch at login for a bundled app.

**Rationale**: the Accessibility grant is keyed to the code signing identity and
bundle id; with ad-hoc signing every rebuild is a new identity and the grant is
lost. One valid identity exists in the keychain (verified with
`security find-identity`). Hardened runtime is enabled for forward compatibility; it
does not block event taps or `dlsym` of system libraries.

## R9. Private API fallback behaviour

**Decision**: `GrabbyPrivate` exposes each private function as an optional function
pointer resolved once at startup. The app reports `smoothAvailable` as true only
when every symbol the Smooth engine needs resolved. Silent failures are detected per
gesture by `SpaceObserver` (active Space id before began, read again 400 ms after
ended; Mission Control presence checked via `CGSCopyManagedDisplaySpaces` window
counts is out of scope for v1, so vertical gestures are verified by API error only).
`FallbackDecider` in GrabbyCore turns those observations into: fire catch-up step,
increment failure count, go sticky.

## Sources

- Mac Mouse Fix repository, files read: Helper/Core/Touch/TouchSimulator.{h,m},
  Helper/Core/Drag/ModifiedDrag.m,
  Helper/Core/Drag/ThreeFingerSwipe/ModifiedDragOutputThreeFingerSwipe.m,
  Helper/Core/Buttons/ButtonInputReceiver.m, Helper/Core/Actions/SymbolicHotKeys.m,
  Helper/Utility/PointerFreeze.m, Shared/IOKit/CGEventHIDEventBridge.m,
  Shared/IOKit/External/IOHIDEventTypes.h, Shared/IOKit/External/IOHIDEventFieldDefs.h,
  Shared/External/CGSInternal/CGSHotKeys.h, Tests/FixDockSwipes.m.
  https://github.com/noah-nuebling/mac-mouse-fix
- Mac Mouse Fix issues 1871, 1876 and pull request 2023 (macOS 27 breakage, hotkey
  fallback, 8 ms coalescing).
- Apple Developer Forums thread 735204 (tap permissions, revocation).
- SensibleSideButtons write-up; Ian Ynda-Hummel on posting Control+Arrow; OpenLogi
  input hook notes (self-event tagging); BetterMouse requirements page.
