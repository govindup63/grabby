# Contract: grabby-probe CLI

Developer tool. Posts one synthetic Dock Swipe and reports whether the active Space
changed, so the Smooth engine's health can be checked from the terminal, independent
of the app. Mirrors the probe used in Mac Mouse Fix pull request 2023.

## Invocation

```text
swift run grabby-probe [--direction left|right] [--repeat N] [--json]
swift run grabby-probe --symbols
swift run grabby-probe --hotkey left|right|mission-control|app-expose|show-desktop
```

Requires Accessibility access for the terminal running it. Needs two or more Spaces
for a horizontal probe to be meaningful.

## Behaviour

- `--symbols`: resolve every private symbol GrabbyPrivate needs and print one line
  per symbol, `OK` or `MISSING`. Exit 0 if all present, 2 otherwise. Posts nothing.
- default (`--direction right`, `--repeat 1`): read active Space, post a began event,
  then changed events ramping progress to 1.0 over 150 ms at one event per 8 ms,
  then ended with exit speed. Wait 400 ms. Read active Space. Print
  `space before=<id> after=<id> changed=<yes|no> elapsed=<ms>`. Repeat N times with
  alternating direction so the desktop ends where it started when N is even.
- `--hotkey X`: trigger the symbolic hotkey through the same code path as the app's
  Keyboard engine, then report the active Space before and after. Verifies the
  rebind-and-restore logic leaves `CGSGetSymbolicHotKeyValue` unchanged, printing the
  binding before and after.
- `--json`: one JSON object per run on stdout, for scripting:
  `{"direction":"right","before":5,"after":6,"changed":true,"elapsedMs":357}`.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | every run changed the Space (or `--symbols` all OK) |
| 1 | at least one run did not change the Space |
| 2 | missing symbol or missing Accessibility access, nothing posted |
| 64 | bad arguments |

## Non-goals

No vertical probe in v1 (Mission Control presence cannot be read reliably without
more private API). The probe shares `DockSwipeEngine` and `HotkeyEngine` code with
the app through a small internal module so it tests the real path.
