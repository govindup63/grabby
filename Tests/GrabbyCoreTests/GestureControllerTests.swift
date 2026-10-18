import Testing
@testable import GrabbyCore

@Suite struct GestureControllerTapTests {
    @Test func tapRunsMissionControlByDefault() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 10, y: 10))
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.missionControl])
        #expect(h.output.dockCalls.isEmpty)
    }

    @Test(arguments: [(TapAction.none, [StepCommand]()),
                      (TapAction.appExpose, [StepCommand.appExpose]),
                      (TapAction.showDesktop, [StepCommand.showDesktop])])
    func tapRunsConfiguredAction(action: TapAction, expected: [StepCommand]) {
        let h = Harness(settings: .defaults.with { $0.tapAction = action })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.actionButtonUp()
        #expect(h.output.steps == expected)
        #expect(h.controller.lastTapWasPassThrough == false)
    }

    @Test func passThroughTapIsFlaggedAndPerformsNothing() {
        let h = Harness(settings: .defaults.with { $0.tapAction = .passThrough })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.actionButtonUp()
        #expect(h.output.calls.isEmpty)
        #expect(h.controller.lastTapWasPassThrough)
    }
}

@Suite struct GestureControllerSmoothTests {
    let smooth = Settings.defaults.with { $0.switchingStyle = .smooth }

    @Test func horizontalDragBeginsChangesEnds() {
        let h = Harness(settings: smooth)
        h.controller.actionButtonDown(at: Point(x: 100, y: 100))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -20, dy: 0)
        h.drag(dx: -20, dy: 0)
        h.controller.actionButtonUp()

        let scaler = SwipeProgressScaler(screen: h.spaces.size, spaceCount: h.spaces.count, naturalDirection: false)
        let first = scaler.horizontalProgress(forDelta: -10)
        #expect(h.output.calls.first == .began(.horizontal, first))
        let begans = h.output.calls.filter { if case .began = $0 { return true } else { return false } }
        #expect(begans.count == 1)
        let changes = h.output.calls.filter { if case .changed = $0 { return true } else { return false } }
        #expect(changes.count == 2)
        guard case .ended(let progress, _)? = h.output.calls.last else {
            Issue.record("expected ended, got \(String(describing: h.output.calls.last))")
            return
        }
        #expect(abs(progress - scaler.horizontalProgress(forDelta: -50)) < 1e-9)
        #expect(h.output.steps.isEmpty)
    }

    @Test func reversedLastDeltaCancels() {
        let h = Harness(settings: smooth)
        h.controller.actionButtonDown(at: Point(x: 100, y: 100))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -20, dy: 0)
        h.drag(dx: 20, dy: 0)
        h.controller.actionButtonUp()
        guard case .cancelled? = h.output.calls.last else {
            Issue.record("expected cancelled, got \(String(describing: h.output.calls.last))")
            return
        }
    }

    @Test func pointerIsPinnedDuringDragWhenEnabled() {
        let h = Harness(settings: smooth)
        let origin = Point(x: 300, y: 200)
        h.controller.actionButtonDown(at: origin)
        h.drag(dx: 9, dy: 0)
        #expect(h.pointer.pinned == [origin])
        #expect(h.pointer.unpinCount == 0)
        h.controller.actionButtonUp()
        #expect(h.pointer.unpinCount == 1)
    }

    @Test func pointerIsNotPinnedWhenDisabled() {
        let h = Harness(settings: smooth.with { $0.pinPointer = false })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 9, dy: 0)
        h.controller.actionButtonUp()
        #expect(h.pointer.pinned.isEmpty)
        #expect(h.pointer.unpinCount == 0)
    }

    @Test func tapDoesNotPin() {
        let h = Harness(settings: smooth)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.actionButtonUp()
        #expect(h.pointer.pinned.isEmpty)
    }

    @Test func verticalUpUsesVerticalDockSwipe() {
        let h = Harness(settings: smooth)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 0, dy: -10)
        guard case .began(.vertical, _)? = h.output.calls.first else {
            Issue.record("expected vertical began, got \(h.output.calls)")
            return
        }
        h.controller.actionButtonUp()
        #expect(h.output.steps.isEmpty)
    }

    @Test func verticalDownShowDesktopAlwaysUsesKeyboardPath() {
        let h = Harness(settings: smooth.with { $0.dragDownAction = .showDesktop })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 0, dy: 10)
        h.drag(dx: 0, dy: 60)
        h.controller.actionButtonUp()
        #expect(h.output.dockCalls.isEmpty)
        #expect(h.output.steps == [.showDesktop])
    }

    @Test func verticalDownNoneDoesNothing() {
        let h = Harness(settings: smooth.with { $0.dragDownAction = .none })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 0, dy: 10)
        h.drag(dx: 0, dy: 200)
        h.controller.actionButtonUp()
        #expect(h.output.calls.isEmpty)
        #expect(h.pointer.pinned.isEmpty)
    }

    @Test func cancelMidDragCancelsAndUnpins() {
        let h = Harness(settings: smooth)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 20, dy: 0)
        h.controller.cancelGesture()
        guard case .cancelled? = h.output.calls.last else {
            Issue.record("expected cancelled, got \(h.output.calls)")
            return
        }
        #expect(h.pointer.unpinCount == 1)
        h.controller.actionButtonUp()
        #expect(h.output.calls.count == 2)
    }

    @Test func smoothUnavailableRoutesVerticalUpToKeyboard() {
        let h = Harness(settings: smooth, smoothAvailable: false)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 0, dy: -10)
        h.drag(dx: 0, dy: -60)
        h.controller.actionButtonUp()
        #expect(h.output.dockCalls.isEmpty)
        #expect(h.output.steps == [.missionControl])
    }
}

@Suite struct GestureControllerSettingsTests {
    @Test func changingTapActionAtRuntimeAffectsNextTap() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.actionButtonUp()
        h.controller.settings.tapAction = .appExpose
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.missionControl, .appExpose])
    }

    @Test func passThroughFlagResetsOnNextButtonDown() {
        let h = Harness(settings: .defaults.with { $0.tapAction = .passThrough })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.actionButtonUp()
        #expect(h.controller.lastTapWasPassThrough)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        #expect(h.controller.lastTapWasPassThrough == false)
        h.controller.settings.tapAction = .none
        h.controller.actionButtonUp()
        #expect(h.controller.lastTapWasPassThrough == false)
    }

    @Test func changingActionButtonIsAccepted() {
        let h = Harness()
        h.controller.settings.actionButton = 3
        #expect(h.controller.settings.actionButton == 3)
    }
}
