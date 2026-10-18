# Data Model: Mouse Action Button

All types live in `GrabbyCore` unless noted. Value types, `Sendable`, `Equatable`.

## Settings

Persisted as JSON (see contracts/settings-schema.json). Loaded once at launch, saved
on every change.

| Field | Type | Default | Validation |
|---|---|---|---|
| `schemaVersion` | Int | 1 | must be 1; unknown versions fall back to defaults |
| `actionButton` | Int? | nil | 2...31; 0 and 1 rejected; nil means not configured, nothing is intercepted |
| `switchingStyle` | enum `smooth`, `keyboard` | `keyboard` until the probe passes, then `smooth` (compile-time default flipped in milestone 2) | |
| `dragDownAction` | enum `appExpose`, `showDesktop`, `none` | `appExpose` | |
| `tapAction` | enum `missionControl`, `appExpose`, `showDesktop`, `none`, `passThrough` | `missionControl` | |
| `naturalDirection` | Bool? | nil | nil means "follow the system natural scrolling setting at launch" |
| `pinPointer` | Bool | true | |
| `launchAtLogin` | Bool | false | mirrored to `SMAppService` status by the app |

Unknown keys are ignored on load. Missing keys take defaults. A file that fails to
decode is renamed `settings.json.broken` and defaults are used.

## Gesture

One press-to-release of the action button. Owned by `GestureRecognizer`.

| Field | Type | Notes |
|---|---|---|
| `origin` | Point | pointer location at button down (app supplies) |
| `offset` | Vector | sum of raw deltas since down |
| `axis` | enum `none`, `horizontal`, `vertical` | locked once `max(abs(x), abs(y)) > 7` |
| `lastDelta` | Double | last delta along the locked axis |
| `startedAt` | Instant | from injected clock |

### State machine

```text
idle --buttonDown--> pressed
pressed --delta(under threshold)--> pressed
pressed --delta(over threshold)--> dragging(axis)     emits dragBegan(axis)
pressed --buttonUp--> idle                            emits tap
dragging --delta--> dragging                          emits dragChanged(deltaAlongAxis)
dragging --buttonUp--> idle                           emits dragEnded
dragging --cancel (device lost, permission lost, quit)--> idle   emits dragCancelled
```

Threshold constant: 7 points. Axis choice: the larger absolute component at the
moment the threshold is crossed; ties go horizontal.

## Engine state

Held by `GestureController`. Not persisted.

| Field | Type | Notes |
|---|---|---|
| `smoothAvailable` | Bool | all private symbols resolved at startup |
| `consecutiveFailures` | Int | reset to 0 on a verified success |
| `stickyFallback` | Bool | set when `consecutiveFailures` reaches 2; cleared only by relaunch |
| `noticeShown` | Bool | the one-time menu bar notice |

Effective engine for a gesture:
`style == .smooth && smoothAvailable && !stickyFallback ? smooth : keyboard`.
Show Desktop is always keyboard.

## Smooth gesture bookkeeping

Held by `EventCoalescer` and `EndPhaseDecider` for the duration of one gesture.

| Field | Type | Notes |
|---|---|---|
| `originOffset` | Double | accumulated progress sent to the Dock |
| `pendingDelta` | Double | motion accumulated since the last sent "changed" |
| `lastSentAt` | Instant | for the 8 ms gate |
| `spaceBefore` | SpaceID (UInt64) | read at began, app supplies |

## Discrete stepping

Held by `DiscreteStepper` for one gesture.

| Field | Type | Notes |
|---|---|---|
| `committed` | Int | steps fired so far, signed by direction |
| `distance` | Double | signed distance along the axis |

Rule: first step when `abs(distance) >= 60`, next steps every further 200 points in
the same direction. Crossing back through zero resets `committed` to 0 and the
thresholds start again on the other side. Vertical gestures fire exactly one step
(Mission Control up, configured action down) and ignore further distance.

## Fallback observation

Input to `FallbackDecider` after a smooth gesture ends.

| Field | Type |
|---|---|
| `axis` | Axis |
| `distance` | Double |
| `spaceBefore` | SpaceID |
| `spaceAfter` | SpaceID |
| `hardError` | Bool |
| `consecutiveFailures` | Int |

Output: `catchUpStep: StepCommand?`, `newFailureCount: Int`, `becameSticky: Bool`.

Rules: a horizontal gesture with `abs(distance) >= 60` whose Space did not change is
a failure and produces a catch-up step in the drag direction. A gesture under 60 is
never a failure. A hard error is always a failure. A success resets the count to 0.

## Conflict

Produced by the app's `ConflictDetector` when Settings appears.

| Field | Type |
|---|---|
| `tool` | enum `betterMouse`, `logitechGHub`, `logitechOptionsPlus` |
| `advice` | String, includes the configured button number |

## StepCommand (system action)

```text
moveSpaceLeft, moveSpaceRight, missionControl, appExpose, showDesktop
```

Mapped by the app's `HotkeyEngine` to symbolic hotkey ids 79, 81, 32, 33, 36.
