# Grabby: rules for agents working in this repository

`CLAUDE.md` and `AGENTS.md` are mirrors. Change one, change the other.

## macOS support is the first priority

Grabby must work on the three current major versions of macOS: **15 (Sequoia), 26 (Tahoe) and 27**. Every feature and every fix is judged against all three, not against the machine it was written on.

- No change may break any of these versions. A change that works on one and regresses another is not done; it is a regression.
- Anything that talks to the system per version (the Dock Swipe event format, private symbols, Accessibility behaviour, symbolic hotkey ids) must be selected at runtime by OS version, never assumed. The Dock Swipe engine already does this: `DockSwipeEngine.formatForThisSystem()` picks the IOHIDEvent format on 27 and the field-based format on 26 and earlier. Follow that pattern.
- Private symbols are resolved with `dlsym` in `Sources/GrabbyPrivate` only, and every call site has a fallback. A missing symbol on any version must degrade (keyboard-shortcut path), never crash and never do nothing silently.
- Known gap as of 2026-10-23: `Package.swift` sets the deployment target to macOS 26, so 15 is not yet buildable. Lowering it, and auditing the APIs used, is the priority item before new features.
- Before merging a change that touches gesture or event code, state in the pull request (or the commit message) which of the three versions it was run on and what happened on the others. Untested versions are called out as untested, not assumed fine.
- Releases are tagged from `main` only, and `main` must build and pass `swift test` on CI before a tag is pushed.

## How changes are made here

- Tests first. Every behaviour in `Sources/GrabbyCore` has a Swift Testing test written and seen failing before the code. `swift test` green is the completion signal for core changes.
- The app layer (taps, posting, private API) is verified on a real mouse. For anything that changes how macOS reacts to events, record the real system first: create `~/Library/Application Support/Grabby/trace.log`, relaunch, do the gesture on a trackpad and on the mouse, compare the recorded Dock Swipe events field by field. Reasoning from other projects' code was wrong four times in this project's history; recordings were right every time.
- Measured facts about macOS behaviour go in `specs/001-mouse-action-button/research.md`.
- No new dependencies. Keep changes small; match the surrounding style; remove code you make obsolete.
- Commits are signed off (`git commit -s`), with no AI attribution lines.

## Layout

See the Layout section of `README.md`. Core logic in `GrabbyCore`, private API in `GrabbyPrivate`, engines in `GrabbyEngines`, app in `GrabbyApp`, developer CLI in `GrabbyProbe`.
