# Feature Specification: Mouse Action Button

**Feature Branch**: `001-mouse-action-button`

**Created**: 2026-10-18

**Status**: Implemented (amended 2026-10-18, see Amendments)

**Input**: User description: "Grabby: macOS menu bar app that turns one spare mouse button into an action button. Hold the action button and drag left/right to switch between desktops (Spaces) following the pointer like a trackpad three-finger swipe; drag up opens Mission Control; drag down is configurable (App Expose, Show Desktop, nothing). Tap without dragging runs a configurable tap action. The action button is chosen by pressing it in a learn step (left and right buttons are never allowed). Switching style is Smooth (synthetic trackpad gesture) or Keyboard shortcut, with automatic fallback to the keyboard path when the smooth path fails. Optional pointer pinning during drag, launch at login, Accessibility permission onboarding, conflict warnings for BetterMouse and Logitech G HUB. Full design with research is in docs/superpowers/specs/2026-10-18-grabby-design.md."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Switch desktops by holding a button and dragging (Priority: P1)

A Mac user with a multi-button mouse holds their chosen action button and moves the
mouse left or right. The desktops slide under the pointer the same way they do with a
three-finger swipe on a trackpad. Releasing the button settles on the nearest desktop.
Moving up while holding opens Mission Control.

**Why this priority**: This is the reason the product exists. Without it there is
nothing to ship.

**Independent Test**: With at least two desktops set up and an action button chosen,
hold the button and drag right, then release. The active desktop changes. Drag the
other way to return. Drag up and Mission Control opens. Left and right clicks behave
exactly as before throughout.

**Acceptance Scenarios**:

1. **Given** two or more desktops and a configured action button, **When** the user
   holds the button and drags horizontally by at least one screen width, **Then** the
   active desktop changes to the neighbour in the direction of the drag.
2. **Given** the user is mid-drag, **When** they move back toward the start and
   release before the half-way point, **Then** the original desktop remains active.
3. **Given** a configured action button, **When** the user holds it and drags upward,
   **Then** Mission Control opens.
4. **Given** the user is dragging, **When** they move the mouse, **Then** the pointer
   stays where the drag started (when pointer pinning is on) and is back under the
   user's control the instant the button is released.
5. **Given** the app is running, **When** the user clicks the left or right button,
   **Then** those clicks reach applications unchanged.

---

### User Story 2 - Choose the action button and what a tap does (Priority: P1)

The user opens Settings, presses "Change", presses the mouse button they want, and
sees it confirmed by number. They pick what a tap (press and release with no movement)
does: Mission Control, App Expose, Show Desktop, nothing, or pass the original click
through. They pick what dragging down does: App Expose, Show Desktop, or nothing.

**Why this priority**: The user's mouse has two spare buttons and one is already taken
by another tool. Choosing the right button is required before story 1 is usable.

**Independent Test**: Open Settings, enter the learn step, press a side button. The
settings show that button. Press the left or right button in the learn step and it is
refused with an explanation. Change the tap action and confirm a tap does the new thing.

**Acceptance Scenarios**:

1. **Given** the learn step is active, **When** the user presses a button other than
   left or right, **Then** that button is recorded as the action button and the learn
   step closes.
2. **Given** the learn step is active, **When** the user presses the left or right
   button, **Then** the press is refused, the button is not changed, and the user is
   told why.
3. **Given** the learn step is active, **When** no button press arrives within ten
   seconds, **Then** the step ends and the user is told that their mouse software may
   have remapped the button.
4. **Given** a tap action is set, **When** the user presses and releases the action
   button without moving, **Then** that action runs and nothing else happens.
5. **Given** settings were changed, **When** the app is quit and relaunched, **Then**
   the same settings are in effect.

---

### User Story 3 - Grant permission and get told about conflicts (Priority: P2)

On first launch the app explains that it needs Accessibility access, offers a button
to open the right system pane, and starts working as soon as access is granted,
without a relaunch. If BetterMouse or Logitech G HUB is running, the settings show a
notice naming the tool and what to do about the chosen button.

**Why this priority**: Without permission the app does nothing. Without the conflict
notice the most likely reason the button "does nothing" goes unexplained.

**Independent Test**: Launch with no permission granted. The onboarding screen
appears. Grant access in System Settings. Within a couple of seconds the status line
reads working and story 1 works. Launch BetterMouse and the notice appears in
Settings.

**Acceptance Scenarios**:

1. **Given** Accessibility access is not granted, **When** the app launches, **Then**
   a screen explains why access is needed and offers to open the system pane, and no
   mouse button is intercepted.
2. **Given** that screen is showing, **When** the user grants access, **Then** the
   app begins working within three seconds without being relaunched.
3. **Given** access is revoked while the app is running, **When** the user next
   clicks the action button, **Then** the click behaves as if the app were not
   running and the status line reports that access is needed.
4. **Given** BetterMouse or Logitech G HUB is running, **When** Settings is opened,
   **Then** a notice names the tool and tells the user to unassign or quit it for the
   chosen button.

---

### User Story 4 - Keyboard style and automatic fallback (Priority: P2)

The user can choose "Keyboard shortcut" style, where a drag past a threshold moves one
desktop at a time instead of sliding smoothly. If "Smooth" style is selected and the
smooth gesture stops working after a system update, the app notices that the desktop
did not change and performs the keyboard-style step instead, so the gesture never
silently does nothing.

**Why this priority**: The smooth behaviour depends on system internals that changed
once this year. The user must never be left with a dead button.

**Independent Test**: Select Keyboard style; a drag of 60 points switches one
desktop, a drag of 260 switches two. Select Smooth style and simulate a failure (the
developer probe reports no desktop change); the next drag still switches desktop and a
one-time notice appears in the menu bar.

**Acceptance Scenarios**:

1. **Given** Keyboard style, **When** the user drags 60 points horizontally while
   holding the button, **Then** the active desktop moves one step in that direction,
   and a further 200 points moves one more.
2. **Given** Keyboard style, **When** the user drags back after a step has fired,
   **Then** the step is not undone.
3. **Given** Smooth style and a drag that crossed the step threshold, **When** the
   desktop has not changed shortly after release, **Then** the keyboard step for that
   gesture fires.
4. **Given** two consecutive smooth failures, **When** the next drag starts, **Then**
   it uses the keyboard path for the rest of the session and the user has been shown a
   one-time notice.
5. **Given** "Show Desktop" is chosen for drag down, **When** the user drags down,
   **Then** Show Desktop runs regardless of the selected style.

---

### User Story 5 - Always on, out of the way (Priority: P3)

The app lives in the menu bar only, with no Dock icon, and can be set to launch at
login. At idle it uses no noticeable CPU.

**Why this priority**: Nice to have for daily use; story 1 to 4 work without it.

**Independent Test**: Enable launch at login, log out and in; the menu bar icon is
present and the action button works. With the button not held, CPU for the app stays
under 1 percent in Activity Monitor.

**Acceptance Scenarios**:

1. **Given** launch at login is enabled, **When** the user logs in, **Then** the app
   is running and the action button works without opening Settings.
2. **Given** the app is running and idle, **When** the user moves the mouse normally
   for a minute, **Then** the app's CPU use stays under 1 percent.

---

### Edge Cases

- Mouse is unplugged or goes to sleep mid-drag: the gesture must end or cancel; the
  pointer must not stay pinned or hidden.
- The app quits or crashes mid-drag: the button must be fully usable by the system
  again, and no desktop transition may stay stuck.
- Only one desktop exists: a horizontal drag does nothing and nothing gets stuck.
- Multiple displays: the drag acts on the display under the pointer where the drag
  began.
- The mouse reports the chosen button as a keystroke or a swipe (firmware remap):
  the learn step reports that nothing arrived.
- Mouse software (BetterMouse, G HUB) is started after the app: the notice appears
  the next time Settings is opened.
- The user picks the middle button as the action button: allowed; middle-click
  pass-through is available via the "pass click through" tap action.
- A 1000 Hz mouse: the slide must stay smooth, not stutter.
- Natural scrolling is off on the system: drag direction follows the user's
  "natural direction" toggle, which defaults to the system setting at launch.
- The user's own Mission Control keyboard shortcuts are changed or disabled: the
  keyboard style still works, and the user's shortcut settings are never left
  modified.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to choose any mouse button other than left and right
  as the action button by pressing it in a learn step.
- **FR-002**: The learn step MUST refuse left and right, explain the refusal, and
  time out after ten seconds with a message about mouse software remapping.
- **FR-003**: While the action button is held, horizontal mouse movement MUST move
  between desktops in the direction of the movement.
- **FR-004**: In Smooth style, desktops MUST follow the pointer continuously during
  the drag and settle on release, with one screen width of movement equal to one
  desktop.
- **FR-005**: In Smooth style, releasing after moving back toward the origin MUST
  return to the original desktop.
- **FR-006**: While the action button is held, upward movement MUST open Mission
  Control.
- **FR-007**: Downward movement MUST run the configured drag-down action: App
  Expose (default), Show Desktop, or nothing.
- **FR-008**: Releasing the action button without movement beyond a small threshold
  MUST run the configured tap action: Mission Control (default), App Expose, Show
  Desktop, nothing, or pass the original click through.
- **FR-009**: The direction of a drag MUST lock to the dominant axis once movement
  passes the threshold, and the other axis MUST be ignored for the rest of that
  gesture.
- **FR-010**: Users MUST be able to choose between Smooth and Keyboard switching
  style; one choice applies to horizontal and vertical drags. Show Desktop always
  uses the keyboard path.
- **FR-011**: In Keyboard style, a step MUST fire at 60 points of drag and every
  further 200 points, during the drag, and MUST NOT be retracted by dragging back.
- **FR-012**: In Smooth style, if a drag crossed the step threshold and the desktop
  did not change after release, the app MUST perform the equivalent keyboard step.
- **FR-013**: After two consecutive smooth failures, the app MUST use the keyboard
  path for the rest of the session, show a one-time notice, and try Smooth again on
  the next launch.
- **FR-014**: Left and right mouse buttons MUST never be intercepted or altered.
- **FR-015**: Users MUST be able to toggle pointer pinning during a drag (default
  on). When on, the pointer stays at the drag origin until release.
- **FR-016**: Users MUST be able to toggle natural direction; the default follows the
  system's natural scrolling setting at launch.
- **FR-017**: The app MUST explain and request Accessibility access on first launch,
  detect when it is granted within three seconds without a relaunch, and intercept
  no buttons while access is missing.
- **FR-018**: If access is revoked while running, the app MUST stop intercepting and
  report that access is needed.
- **FR-019**: Settings MUST show a conflict notice when BetterMouse or Logitech G HUB
  is running, naming the tool and the chosen button.
- **FR-020**: All settings MUST persist across relaunches and across login.
- **FR-021**: The app MUST run in the menu bar only, with no Dock icon, and MUST
  offer a launch-at-login toggle.
- **FR-022**: Every drag that begins MUST end or cancel, including on quit, crash,
  device loss, or permission loss, leaving no stuck transition and no pinned or
  hidden pointer.
- **FR-023**: The app MUST never leave the user's system keyboard shortcut settings
  modified after a gesture.

### Key Entities

- **Settings**: the user's configuration. Action button number; switching style;
  drag-down action; tap action; natural direction; pointer pinning; launch at login.
- **Gesture**: one press-to-release of the action button. Has an origin, an
  accumulated offset, a locked axis (or none), and an outcome: tap, drag ended, or
  drag cancelled.
- **Engine**: the mechanism that carries out a gesture: Smooth or Keyboard. Has a
  failure count for the session and a sticky-fallback flag.
- **Conflict**: a known third-party mouse tool detected as running, with the advice
  to show.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user with a two-side-button mouse can go from first launch to
  switching desktops with the action button in under two minutes, including
  granting permission and choosing the button.
- **SC-002**: In Smooth style on a supported system, 19 of 20 horizontal drags of one
  screen width land on the neighbouring desktop; the remaining one is caught by the
  keyboard fallback so that 20 of 20 change desktop.
- **SC-003**: Desktop motion visibly tracks the pointer with no stutter on a 1000 Hz
  mouse; a release mid-way snaps back within half a second.
- **SC-004**: Zero left or right clicks are lost or altered over a full working day.
- **SC-005**: After quitting the app, the action button returns to its original
  behaviour immediately, every time.
- **SC-006**: Idle CPU use stays under 1 percent; memory under 50 MB.
- **SC-007**: Permission grant is detected and the app starts working within three
  seconds without a relaunch.

## Assumptions

- The user runs macOS 27 on Apple silicon; older systems are not targeted.
- One mouse at a time; settings are global, not per device or per application.
- The user is willing to grant Accessibility access; the app is distributed outside
  the Mac App Store.
- The user has not assigned the chosen button to anything in Logitech G HUB or
  BetterMouse; if they have, the conflict notice tells them to undo it.
- The defaults chosen in the design document stand unless the user changes them:
  tap runs Mission Control, drag down runs App Expose, pointer pinning on, Smooth
  style once verified on the user's machine, Keyboard style until then.
- Scrolling, pointer acceleration, per-app rules and multiple profiles are out of
  scope.

## Amendments (2026-10-18, after hands-on testing)

The following supersede the matching requirements above. They came from recording real
trackpad Dock Swipe events on macOS 27 and from the user's testing.

- Release semantics (FR-004, FR-005, FR-011 to FR-013): the Dock decides whether a
  release completes or slides back from the release position and velocity, exactly as
  with a trackpad. Grabby always reports "ended" with the measured hand velocity scaled
  by the Throw setting (0 to 1, default 0.35). The keyboard style is no longer a user
  choice; it remains only as the fallback for hard API errors (two in a row make it
  sticky for the session). No silent-failure detection.
- Scale and direction (FR-004): one screen width plus 63 points of pointer travel is one
  desktop, whatever the Space count; leftward motion is negative progress, as a finger
  is. One progress update per frame of the display under the pointer.
- Tap (FR-008): default is Nothing. Mission Control, App Expose, Show Desktop and pass
  the click through remain selectable.
- Drag down (FR-007): closes Mission Control when it is open (detected from the Dock's
  full-display windows); otherwise nothing. The drag-down picker is removed.
- Pointer pinning (FR-015): removed. The pointer always travels with the hand.
- New: hold plus left click triggers the system area screenshot (symbolic hotkey 30);
  hold plus right click opens the screenshot and recording panel (184). The click is
  swallowed. Only the first click in a hold fires, and it cancels any drag in progress.
- New safety rule (FR-014 family): if the left or right button is already down when the
  action button is pressed, Grabby lets the action button through untouched, down and
  up, so it can never interfere with a drag-and-drop session.
- Settings window: status, action button with learn step, Direction (follow system,
  natural, reversed), Throw, tap action, two fixed rows describing the hold-click
  actions, launch at login, conflicts. Nothing else.
