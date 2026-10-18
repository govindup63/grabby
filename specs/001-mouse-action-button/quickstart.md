# Quickstart: Mouse Action Button

How to build, test and verify Grabby on this machine. Implementation details are in
tasks.md; this is the run and check guide.

## Prerequisites

- macOS 27.0, Apple silicon, Command Line Tools with Swift 6.4 (`swift --version`).
  Xcode is not required.
- An "Apple Development" signing identity in the keychain
  (`security find-identity -v -p codesigning` lists one).
- A mouse with at least one button besides left and right, plugged in.
- Two or more desktops in Mission Control.
- BetterMouse quit. In Logitech G HUB, the button you will use set to its default.

## Unit tests (constitution: these come first)

```bash
swift test
```

Expected: every test in `Tests/GrabbyCoreTests` passes, output ends with
`Test run with N tests ... passed`. During development a new test must be seen
failing first; `swift test --filter GestureRecognizerTests` narrows the run.

The Package.swift carries the three flags that make Swift Testing load on Command
Line Tools (see research.md R1). If `swift test` reports "plugin for module
'TestingMacros' not found" or "Library not loaded", those flags are missing or the
Command Line Tools moved.

## Build and bundle the app

```bash
scripts/bundle.sh
```

Expected: `build/Grabby.app` exists, `codesign -dv build/Grabby.app` shows
`Authority=Apple Development`, and `plutil -p build/Grabby.app/Contents/Info.plist`
shows `LSUIElement => 1` and `CFBundleIdentifier => com.pixelstwo.grabby`.

```bash
open build/Grabby.app
```

Expected: a menu bar icon appears, no Dock icon.

## Watch the logs

```bash
log stream --predicate 'subsystem == "com.pixelstwo.grabby"' --level debug
```

Keep this open during the checklist. Gesture begin, each coalesced send, end phase,
verification result and any fallback decision are logged at debug level.

## Symbol and smooth-path probe

```bash
swift run grabby-probe --symbols
swift run grabby-probe --repeat 6
```

Expected: all symbols `OK`; six runs, each `changed=yes`, exit 0. If `--symbols` fails,
Smooth is unavailable on this macOS and the app will run Keyboard style; that is the
designed behaviour, not a bug in the app, but the plan's milestone 2 default flip
must not happen until the probe passes.

## Runtime checklist (run after every change to the app layer)

Permission flow

1. Remove Grabby from System Settings > Privacy & Security > Accessibility if present.
   Launch the app. Expected: onboarding window explains access, "Open System
   Settings" button works, clicking any mouse button behaves normally.
2. Grant access. Expected: within 3 seconds the window changes to "Grabby is
   working", no relaunch.

Learn step

3. Settings > Change. Press the side button. Expected: "Button 4" (or whichever)
   shown, learn step closes, settings.json contains `"actionButton": 4`.
4. Settings > Change. Press left. Expected: refused with explanation, button
   unchanged. Same for right.
5. Settings > Change, press nothing for 10 seconds. Expected: times out with the
   mouse-software message.

Gestures, Keyboard style

6. Set style to Keyboard. Hold the action button, move right about 60 points,
   release. Expected: desktop moves one to the right. Log shows
   `step moveSpaceRight`.
7. Hold, move right about 300 points. Expected: two desktop moves.
8. Hold, move right 100 then back left 100, release. Expected: one move right,
   not undone.
9. Hold, move up. Expected: Mission Control opens once. Press Escape.
10. Hold, move down. Expected: App Expose (default). Change drag down to Show
    Desktop; repeat; expected Show Desktop.

Gestures, Smooth style (only after the probe passes)

11. Set style to Smooth. Hold and drag right slowly. Expected: the desktops slide
    with the pointer with no stutter; release past half way settles on the next
    desktop; log shows one `changed` send per 8 ms or slower.
12. Drag right a quarter screen and release. Expected: snaps back to the original
    desktop within half a second; log shows `phase=cancelled`.
13. Hold and drag up. Expected: Mission Control opens following the drag.
14. Simulated failure: run with `GRABBY_FAKE_SMOOTH_FAILURE=1` in the environment
    (the Smooth engine posts nothing). Drag right past 60 points twice. Expected:
    each drag still switches desktop via catch-up, the second drag triggers the
    one-time notice, log shows `fallback sticky=true`, and a third drag logs
    `engine=keyboard` from the start.

Tap and pass-through

15. Tap the action button without moving. Expected: Mission Control (default).
16. Set tap to "Pass click through". In a browser, tap. Expected: the browser goes
    Back (or whatever the button did before Grabby).

Pointer and safety

17. With pinning on, drag: the pointer stays put, and moves normally the instant the
    button is released. Turn pinning off: the pointer travels during the drag.
18. Throughout, left and right clicks work in every app.
19. Quit Grabby from the menu bar mid-drag (hold the button, use the keyboard to
    quit). Expected: no stuck transition, the button works normally afterwards.
20. Revoke Accessibility while running. Expected: within 5 seconds the status line
    says access is needed and the action button behaves normally.

Idle cost

21. Activity Monitor, Grabby process, move the mouse around for a minute without
    holding the button. Expected: CPU under 1 percent, memory under 50 MB.

Launch at login

22. Enable the toggle, log out and in. Expected: menu bar icon present, step 6 works.

## Conflicts

23. Launch BetterMouse, open Grabby Settings. Expected: notice naming BetterMouse and
    the button number. Quit BetterMouse, reopen Settings: notice gone. With the G HUB
    agent running (it is, on this machine), the G HUB notice is always shown.
