# Contributing to Grabby

Thanks for looking. This is a small project with a small surface, so the rules are short.

## Setup

macOS 26 or later, Swift 6, and the Command Line Tools. Xcode works too but is not required.

```bash
git clone https://github.com/govindup63/grabby.git
cd grabby
swift test
scripts/run-dev.sh
```

`run-dev.sh` builds a release binary, wraps it in `build/Grabby.app`, signs it with the first signing identity in your keychain (or ad hoc with `GRABBY_SIGN_IDENTITY=-`), and launches it. Grant it Accessibility access once; a stable signing identity keeps that grant across rebuilds.

## How changes are made

Tests first. Every behaviour in `GrabbyCore` has a Swift Testing test that was written and seen failing before the code. If you change gesture logic, change or add the test first and watch it fail. `swift test` passing is the signal that a core change is done.

The app layer (event taps, posting, private API) cannot be unit tested honestly. Verify it on a real mouse, and if the change touches how macOS reacts to events, record the real system first: create `~/Library/Application Support/Grabby/trace.log`, relaunch, do the gesture on a trackpad and on the mouse, and compare the recorded Dock Swipe events field by field. Several "obvious" fixes in this project's history were wrong until a recording settled them.

Keep changes small and focused. Match the surrounding style. Do not add dependencies; the project has none and the private-API surface is already as much risk as it wants.

## Where things go

- Gesture logic, scaling, release rules, settings: `Sources/GrabbyCore` with a test in `Tests/GrabbyCoreTests`.
- Anything that names a private macOS symbol: `Sources/GrabbyPrivate` only, resolved with `dlsym`, with a fallback at the call site.
- Engines that post events or read system state: `Sources/GrabbyEngines`.
- Menu bar, windows, taps, permissions: `Sources/GrabbyApp`.
- Measured facts about macOS behaviour: `specs/001-mouse-action-button/research.md`.

## Commits and pull requests

- One logical change per commit, with a message that says what changed and why.
- Sign off commits (`git commit -s`).
- CI runs `swift build` and `swift test` on a macOS runner for every push and pull request.
- Describe how you verified the change on a real mouse in the pull request.

## Releases

Maintainers tag `vX.Y.Z` on `main`; the release workflow builds, bundles, signs and publishes `Grabby.app.zip`. Update `CHANGELOG.md` and the version in `Sources/GrabbyApp/Resources/Info.plist` in the same commit as the tag.

## Reporting a problem

Open an issue with your macOS version, your mouse and its software (G HUB, Options+, BetterMouse), the button you use, and what you expected. If the gesture misbehaves, attach the trace file described above; it is plain text and contains no personal data beyond timestamps and gesture numbers.
