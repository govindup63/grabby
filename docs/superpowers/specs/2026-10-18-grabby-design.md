# Grabby: design

Date: 2026-10-18
Status: draft for review

## What this is

Grabby is a small macOS menu bar app that turns one spare mouse button into an
"action button". Hold the action button and move the mouse, and the Mac behaves as
if you were doing a three-finger swipe on a trackpad: drag left or right to slide
between desktops (Spaces), drag up to open Mission Control. Tap the button without
moving and a separate, configurable thing happens.

It does one thing. BetterMouse, Mac Mouse Fix and BetterTouchTool all do this, but
bundled with scrolling, acceleration, per-app rules and a price tag or a large
codebase. Grabby is the one feature, free, and owned by its user.

## Why

The user has a Logitech mouse with two spare side buttons. One already triggers
Wispr Flow (dictation). The other is unused. On a trackpad, moving between desktops
is a three-finger slide; on a mouse it is Control+Left/Right, which needs the other
hand. The user wants the second side button to do the slide.

BetterMouse 1.6 is installed on the machine and does this, but it is paid, and the
user wants only this feature. Mac Mouse Fix is open source, but its "Click and Drag"
gesture broke on macOS 27 and the fix had not shipped in a release as of September
2026. The user is on macOS 27.0 (build 26A428).

## Goals

- Pick any mouse button other than left and right as the action button, by pressing
  it in a "press the button now" learn step.
- Hold action button and drag horizontally: move between Spaces, following the
  pointer the way a three-finger swipe does.
- Hold action button and drag vertically: open Mission Control (up). Down is
  configurable (App Expose, Show Desktop, or nothing).
- Tap the action button without dragging: run a configurable tap action.
- Work on macOS 27.0 today, and degrade to a keyboard-shortcut fallback rather than
  silently doing nothing when the smooth path fails.
- Start at login, live in the menu bar only, use well under 1 percent CPU at idle.

## Non-goals

- Scroll smoothing, acceleration curves, scroll direction, or anything about the
  wheel.
- Per-application settings.
- Multiple mice with different profiles. One global configuration.
- Mac App Store distribution. The app needs Accessibility access and posts
  synthetic input, which the sandbox does not allow.
- Remapping the left or right button. Grabby never intercepts them.
- Replacing Logitech G HUB or BetterMouse for anything else they do.

## Anti-goals (would make it a failure even if it "works")

- Swallowing a click the user did not assign. If the tap cannot be created, or the
  app is in a bad state, every button must behave as if Grabby were not running.
- Leaving a Space transition stuck half way, or leaving the pointer hidden or
  pinned after the button is released. Every drag that begins must end or cancel.
- Permanently changing the user's keyboard shortcut settings. If the fallback has to
  touch the system hotkey table, it restores it immediately.
- Needing Xcode to build. The machine has Command Line Tools and Swift 6.4 only.

## How the existing tools do it (research summary)

Three sources were read closely: the Mac Mouse Fix source on GitHub (TouchSimulator,
ModifiedDrag, ModifiedDragOutputThreeFingerSwipe, ButtonInputReceiver,
SymbolicHotKeys, PointerFreeze), the Mac Mouse Fix macOS 27 issues and pull requests
(#1871, #1876, #2023), the SensibleSideButtons write-up, Ian Ynda-Hummel's post on
Spaces, the OpenLogi input-hook notes, and an Apple Developer Forums thread where an
Apple engineer explains event-tap permissions.

Input side, everyone agrees:

- A `CGEventTap` at `kCGHIDEventTap`, `kCGHeadInsertEventTap`,
  `kCGEventTapOptionDefault`, masked to `otherMouseDown` and `otherMouseUp`. Side
  buttons arrive as "other" mouse events with `kCGMouseEventButtonNumber` 3 and 4
  (0 is left, 1 right, 2 middle).
- Returning `nil` from the callback swallows the event. That is how the button's
  original meaning is suppressed.
- Drag tracking uses the `otherMouseDragged` events while the button is held,
  reading `kCGMouseEventDeltaX` and `DeltaY` (raw device deltas, independent of
  pointer position).
- The system disables a tap whose callback is slow
  (`kCGEventTapDisabledByTimeout`). The callback must re-enable it.
- Synthetic events must be tagged (a user-data value on the `CGEventSource`) so the
  app's own tap ignores them and does not loop.
- Permission: a `kCGEventTapOptionDefault` tap and `CGEventPost` both need the
  Accessibility grant. `CGEvent.tapCreate` returns `nil` when it is missing, which is
  the reliable way to detect it; `AXIsProcessTrusted()` can lie after revocation.
  BetterMouse's own docs say Input Monitoring is not needed, and Mac Mouse Fix only
  asks for Accessibility.

Output side, there are two very different ways to "switch Space":

1. Smooth (the trackpad way). Post synthetic Dock Swipe gesture events with a
   progress value that tracks the pointer. macOS animates the Spaces strip under the
   pointer and settles when the gesture ends. This is what Mac Mouse Fix and
   BetterMouse do. It is entirely private API. Before macOS 27 it was done by
   writing undocumented integer fields on a `CGEvent`. On macOS 27 those fields are
   ignored; Mac Mouse Fix now builds an `IOHIDEvent` of type DockSwipe (motion,
   flavor, progress fields; a Velocity child event on end) and attaches it to a type
   30 `CGEvent` with `CGEventSetHIDEvent`, posting at `kCGSessionEventTap`. Pull
   request #2023 measured this at 6 of 6 Space switches on 27.0, where the old
   approach got 0 of 6.
   Details that matter, all from the Mac Mouse Fix source:
   - Progress scaling so one screen width of drag is one Space:
     `offsetForOneSpace = spaces <= 1 ? 2 : 1 + 1/(spaces-1)`, then
     `scale = offsetForOneSpace / (screenWidth + 63)`. Vertical is `1 / screenHeight`.
     Space count per display comes from `CGSCopyManagedDisplaySpaces`.
   - A 1000 Hz mouse floods the Dock with up to 19 progress events per 8 ms frame and
     the animation stutters. Coalesce "changed" events to one per 8 ms, accumulating
     the deltas; never throttle began, ended or cancelled.
   - If the final delta points the opposite way from the accumulated offset, send
     "cancelled" instead of "ended" so the Space snaps back.
   - Under load the end event is sometimes dropped and the transition sticks. Resend
     the end event after 200 ms and 500 ms.
   - Mac Mouse Fix notes a remaining macOS 27 beta bug where transitions
     occasionally stick even so.
2. Discrete (the keyboard way). Trigger the system's own "Move left a space",
   "Move right a space" and "Mission Control" actions. Posting Control+Arrow as
   keyboard events works but only if the user has not changed those shortcuts (on
   this machine they are at defaults). Mac Mouse Fix instead reads the current
   binding for the symbolic hotkey (IDs 79, 81, 32, 33, 36) with
   `CGSGetSymbolicHotKeyValue`, posts that key combination, and if the hotkey is
   disabled or unreachable, temporarily binds it to an out-of-reach virtual key code,
   posts it, and restores the binding. This path is what Mac Mouse Fix users patched
   in as a workaround when the smooth path broke (#1876), and it has not broken
   across macOS releases.

Pointer handling: Mac Mouse Fix pins the pointer at the drag origin during the
gesture by warping it back on every move event (`CGWarpMouseCursorPosition`), so the
cursor does not fly off screen while you slide desktops. It is a user setting there.

Hardware wrinkle: some Logitech mice (MX Master) emit their side buttons as
three-finger swipe gestures, not button clicks, depending on firmware and driver.
On this machine Logitech G HUB is running, which can also remap buttons to key
presses in firmware. The learn step must show what actually arrives, and the
onboarding must tell the user to unassign the button in G HUB and quit BetterMouse.

## Design

### Shape

One process. A menu bar app (`LSUIElement`), no Dock icon, with a Settings window.
Mac Mouse Fix splits into a UI app and a helper agent; that is more than this needs.
Launch at login via `SMAppService`.

Written in Swift 6 with AppKit for the status item and event taps and SwiftUI for the
Settings window. Built with Swift Package Manager (no Xcode on the machine): an
executable target plus a script that assembles the `.app` bundle (Info.plist,
icon), and code-signs it with the "Apple Development" identity already in the
keychain. Signing with a stable identity matters: the Accessibility grant is keyed
to the code signature, and an ad-hoc-signed binary loses the grant on every rebuild.

Private API calls are declared in one C header inside a small C target
(`GrabbyPrivate`), linked against CoreGraphics, IOKit and SkyLight as needed. No
other file touches them. Each private call is wrapped in a Swift function that can
fail, and failures route to the discrete engine.

### Modules

Everything that can be tested without a mouse lives in a library target with no
AppKit dependency, `GrabbyCore`. The app target is thin glue.

GrabbyCore:

- `GestureRecognizer`: a state machine fed with button down, button up and
  (dx, dy) delta events, time-stamped. States: idle, pressed (button down, under
  threshold), dragging (axis locked), ended. Emits: `tap`, `dragBegan(axis)`,
  `dragChanged(delta along axis)`, `dragEnded`, `dragCancelled`. Axis lock happens
  when `max(|x|, |y|)` of the accumulated offset exceeds 7 points (the Mac Mouse Fix
  value), picking the larger component. Once locked, the other axis is ignored for
  that gesture.
- `SwipeProgressScaler`: pure math from the Mac Mouse Fix formula above. Input:
  screen size, Space count, natural-direction flag. Output: progress per point.
- `EventCoalescer`: collapses changed events to one per 8 ms, accumulating deltas,
  passing began/ended/cancelled through immediately. Clock injected.
- `EndPhaseDecider`: decides ended versus cancelled from last delta sign and
  accumulated offset sign.
- `DiscreteStepper`: for the keyboard engine. Converts accumulated drag distance
  into "step left", "step right", "open Mission Control" commands with a commit
  threshold (my call: 60 points for the first step, one more step per further 200
  points, so a long drag crosses several desktops; vertical fires once per gesture).
  Steps fire during the drag, the moment the threshold is crossed, and are final:
  dragging back does not retract a posted step (there is no undo for a posted
  keystroke). Reversing direction past the origin starts counting steps the other
  way from a fresh threshold.
- `FallbackDecider`: given the gesture's distance, the Space id before and after,
  and the failure counter, decides whether the Keyboard engine must fire a catch-up
  step and whether the fallback becomes sticky.
- `Settings`: Codable value type with defaults; persisted as JSON in
  `~/Library/Application Support/Grabby/settings.json`.
- Protocols for the side effects: `GestureOutput` (began/changed/ended/cancelled for
  smooth; step commands for discrete), `SystemActionRunner`, `PointerPin`. The app
  implements them; tests use fakes.

App target:

- `ButtonTap`: owns the `CGEventTap`. Swallows the configured button's down and up.
  Enables a second tap for `otherMouseDragged` and `mouseMoved` only while the button
  is held (so there is zero per-move work when idle). Re-enables on timeout. Ignores
  events tagged with Grabby's own source user-data. Runs on a dedicated thread with
  its own run loop, as Mac Mouse Fix does, so UI work never stalls the callback.
- `DockSwipeEngine`: the smooth engine. Builds the IOHIDEvent per the macOS 27
  recipe, posts it, resends end events at 200 and 500 ms. Only compiled in for
  macOS 27 and later paths; earlier `CGEvent` field recipe is not included (the
  machine is on 27, and the old recipe is dead on 27).
- `HotkeyEngine`: the discrete engine. Reads the symbolic hotkey binding, posts the
  key combination with explicit, clean modifier flags; the temporary-rebind trick
  only when the binding is disabled, always restored in a `defer`.
- `PointerPinner`: warps the pointer back to the origin during a drag, optional.
- `Permissions`: tries to create the tap; on `nil`, shows the onboarding screen with
  a button that opens the Accessibility pane, and retries on a 1 s timer until it
  succeeds.
- `LearnButtonController`: for the learn step, listens (listen-only tap) to all
  other-button events for up to 10 s, shows the button number that arrived, refuses
  0 and 1, and warns if nothing arrived ("your mouse software may have remapped this
  button").
- Settings window and status item menu.

### Behaviour

Action button down:

- Swallow it. Start the gesture recognizer. Start the move tap. Record origin.

Pointer moves while held:

- Feed deltas. On axis lock: if horizontal, tell the active engine `began`; pin the
  pointer if enabled. If vertical, same with vertical type.
- On changed: smooth engine gets coalesced progress; discrete engine gets stepper
  commands.

Action button up:

- If still under threshold: it was a tap. Run the tap action.
- If dragging: `ended` or `cancelled` to the engine, unpin the pointer, stop the move
  tap.

Engines:

- Setting "Switching style": Smooth (default) or Keyboard. One switch, and it
  applies to both axes: horizontal Space switching and vertical Mission Control /
  App Expose are all Dock Swipe motions and go through the same engine. Show
  Desktop is not a Dock Swipe motion and always goes through the Keyboard engine.
- The smooth path can fail two ways, and both are handled:
  - Hard failure: a private symbol is missing or `CGEventSetHIDEvent` returns an
    error. If this happens before `began`, the gesture runs on the Keyboard engine.
    If it happens mid-gesture, the engine sends `cancelled`, then the Keyboard engine
    fires the equivalent step for the distance dragged so far.
  - Silent failure (the kind macOS 27 actually produced: events post fine, the Dock
    ignores them). Grabby reads the active Space (`CGSGetActiveSpace`) at `began` and
    again 400 ms after `ended`. If the drag crossed the discrete commit threshold and
    the Space did not change (or, for vertical, Mission Control did not appear), the
    Keyboard engine fires the step the gesture should have produced. `GestureOutput`
    therefore reports back a result, and the discrete engine is always loaded.
  - Two consecutive failures of either kind make the fallback sticky for the rest of
    the process, log it, and show a one-time menu bar notice. The next launch tries
    Smooth again.
- The command-line probe is a developer tool only. Grabby never runs it at launch
  (it would visibly move the desktop every login). The builder runs it once on this
  machine; when it passes, Smooth ships as the compiled default.

Tap action options: Mission Control, App Expose, Show Desktop, Nothing, Pass the
click through (replays the original button down and up, tagged). Default: Mission
Control (my call; it is what both BetterMouse and Mac Mouse Fix users expect from a
spare button, and it means the button is useful even before the user learns the
drag).

Vertical drag down: App Expose by default (matches the trackpad's four-finger down).

Natural direction: a toggle. Default follows the system's "Natural scrolling"
setting at launch, as Mac Mouse Fix does.

Multi-display: Space count and screen size are read for the display under the
pointer at gesture start.

Idle cost: with the button not held, the only live tap is the button tap, which only
fires for other-button clicks. No move events are processed.

### Settings window

Single pane, in this order:

1. Status line: "Grabby is working" or "Needs Accessibility access" with a button.
2. Action button: shows "Button 4" and a "Change..." button that enters the learn
   step ("Press the mouse button you want to use. Left and right are not allowed.").
3. Style for all drags: Smooth / Keyboard shortcut. Natural direction toggle.
4. Drag left or right: Switch desktop (fixed). Drag up: Mission Control (fixed).
   Drag down: App Expose / Show Desktop / Nothing.
5. Tap: Mission Control / App Expose / Show Desktop / Nothing / Pass click through.
6. Keep pointer in place while dragging: toggle, default on.
7. Launch at login: toggle.
8. Conflicts box, shown only when relevant: "BetterMouse is running. Quit it or
   unassign button N there." Same for Logitech G HUB if its agent is running
   ("make sure button N is set to its default in G HUB").

### Testing approach (constitution: tests first)

GrabbyCore is pure and gets `swift test` coverage before any of it is written:

- Recognizer: tap under threshold; axis lock picks the larger component at exactly
  the threshold; opposite axis ignored after lock; up during drag emits ended.
- Scaler: one screen width plus 63 points maps to exactly one Space for 2, 3 and 5
  Spaces; single-Space case uses 2.
- Coalescer: 19 changed events inside 8 ms become one with the summed delta; began
  and ended are never delayed; no motion is lost across skipped events.
- End decider: same sign ended, opposite sign cancelled, zero last delta ended.
- Stepper: first step at 60, second at 260, vertical fires once; dragging back
  after a step does not retract it; crossing the origin resets the count.
- Fallback decider: Space unchanged after a committed drag fires one catch-up step;
  Space changed fires nothing; sub-threshold drags never fire; second consecutive
  failure sets sticky.
- Settings: round-trips through JSON; unknown keys ignored; defaults applied.

The app layer (taps, posting, private API) cannot be unit tested honestly. It is
verified at runtime with a checklist the builder runs on the real mouse: button is
swallowed, drag switches Space in both directions and follows the pointer, release
mid-way snaps back (smooth style only), Mission Control opens on drag up, tap action fires, pointer does
not drift, left and right clicks untouched, revoking Accessibility shows the prompt
and nothing is swallowed, quitting Grabby restores the button fully. One probe in
the repo posts a single synthetic Dock Swipe and reads the active Space before and
after (`CGSGetActiveSpace`) so the smooth engine's health can be checked from the
command line, the way pull request #2023 did.

### Milestones

1. Core library with tests. Menu bar app, permission flow, learn step, button
   swallowing, Keyboard engine, tap action. Usable end to end on day one.
2. Smooth engine behind the "Smooth" style, with the probe. Default flips to Smooth
   once the probe passes on the user's machine.
3. Pointer pinning, conflicts box, launch at login, signing script.

## Constraints

- macOS 27.0 (26A428), Apple silicon, Swift 6.4, Command Line Tools only.
- Build and sign from the terminal. One Apple Development identity is available.
- Accessibility permission is required and is requested once, with a clear screen.
- The smooth engine depends on private API that Apple changed once already this
  year. It must be isolated, optional, and fall back.

## Decided by the user

- One spare button becomes an action button; which button is chosen by pressing it.
- Hold and drag reproduces the trackpad three-finger swipe: Spaces left and right,
  Mission Control up. "Make it configurable."
- Only this feature. Not a BetterMouse replacement.

## My calls (change freely)

- Swift and SwiftPM, single process, menu bar only.
- Smooth engine is the default once it passes the probe; Keyboard engine is the
  fallback and the milestone 1 behaviour.
- One style switch for both axes. Vertical Mission Control and App Expose use the
  smooth engine too; Show Desktop is always keyboard-driven.
- Silent smooth failures are detected per gesture by comparing the active Space
  before and after, and caught up with a keyboard step. Two failures in a row make
  the fallback sticky until the next launch. The probe is build-time only.
- Keyboard steps fire mid-drag at the threshold and are never retracted.
- Tap action default: Mission Control. Drag down default: App Expose.
- Drag threshold 7 points; discrete commit 60 then every 200 points.
- Pointer pinning on by default.
- Left and right buttons can never be the action button.
- Private API lives in one C target and nowhere else.

## Left to the builder

- Exact IOHIDEvent field constants and the SkyLight versus CoreGraphics symbol for
  `CGEventSetHIDEvent`; copy from Mac Mouse Fix master and verify with the probe.
- Thread and run loop layout for the taps.
- Settings window visuals.
- App icon.
- Whether the move tap should also mask `mouseMoved` (some mice report moves rather
  than drags for other buttons); decide by logging on the real device.

## Sources

- Mac Mouse Fix source, Helper/Core/Touch/TouchSimulator.m,
  Helper/Core/Drag/ModifiedDrag.m,
  Helper/Core/Drag/ThreeFingerSwipe/ModifiedDragOutputThreeFingerSwipe.m,
  Helper/Core/Buttons/ButtonInputReceiver.m, Helper/Core/Actions/SymbolicHotKeys.m,
  Helper/Utility/PointerFreeze.m: https://github.com/noah-nuebling/mac-mouse-fix
- Mac Mouse Fix macOS 27 breakage and fix:
  https://github.com/noah-nuebling/mac-mouse-fix/issues/1871,
  https://github.com/noah-nuebling/mac-mouse-fix/issues/1876,
  https://github.com/noah-nuebling/mac-mouse-fix/pull/2023
- SensibleSideButtons technical write-up: https://sensible-side-buttons.archagon.net/
- Accessibility, windows and Spaces in OS X (posting Control+Arrow, modifier
  leakage): https://ianyh.com/blog/accessibility-windows-and-spaces-in-os-x
- OpenLogi input hook notes (device filtering, synthetic event tagging):
  https://instagit.com/AprilNEA/OpenLogi/openlogi-button-remapping-input-hook/
- Apple Developer Forums, event tap permissions and revocation behaviour:
  https://developer.apple.com/forums/thread/735204
- BetterMouse feature and requirements page: https://better-mouse.com/
- BetterTouchTool drag triggers: https://docs.folivora.ai/docs/normal-mouse/assigning-actions/
- Hammerspoon hs.eventtap (button numbering): https://www.hammerspoon.org/docs/hs.eventtap
