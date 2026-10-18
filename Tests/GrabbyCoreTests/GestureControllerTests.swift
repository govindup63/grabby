import Testing
@testable import GrabbyCore

@Suite struct GestureControllerTapTests {
    @Test func tapDoesNothingByDefault() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 10, y: 10))
        h.controller.actionButtonUp()
        #expect(h.output.calls.isEmpty)
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
    let smooth = Settings.defaults.with { $0.switchingStyle = .smooth; $0.pinPointer = true }

    @Test func horizontalDragBeginsChangesEnds() {
        let h = Harness(settings: smooth.with { $0.throwStrength = 0 })
        h.controller.actionButtonDown(at: Point(x: 100, y: 100))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -300, dy: 0)
        h.drag(dx: -300, dy: 0)
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
        #expect(abs(progress - scaler.horizontalProgress(forDelta: -610)) < 1e-9)
        #expect(h.output.steps.isEmpty)
    }

    @Test func shortDragStillEndsAndLetsTheDockSlideBack() {
        let h = Harness(settings: smooth.with { $0.throwStrength = 0 })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -40, dy: 0)
        h.controller.actionButtonUp()
        guard case .ended(let progress, let speed)? = h.output.calls.last else {
            Issue.record("expected ended, got \(h.output.calls)")
            return
        }
        #expect(progress < 0)
        #expect(speed == -ReleaseDecider.minimumNudge)
    }

    @Test func reversalEndsWithVelocityInTheNewDirection() {
        let h = Harness(settings: smooth.with { $0.throwStrength = 1 })
        h.controller.actionButtonDown(at: Point(x: 100, y: 100))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -200, dy: 0)
        h.drag(dx: 150, dy: 0)
        h.controller.actionButtonUp()
        guard case .ended(_, let speed)? = h.output.calls.last else {
            Issue.record("expected ended, got \(h.output.calls)")
            return
        }
        #expect(speed > 0)
    }

    @Test func userCancelSendsCancelled() {
        let h = Harness(settings: smooth)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -40, dy: 0)
        h.controller.cancelGesture()
        guard case .cancelled? = h.output.calls.last else {
            Issue.record("expected cancelled, got \(h.output.calls)")
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

    @Test func verticalDownExitsMissionControlOnlyWhenItIsOpen() {
        let closed = Harness(settings: smooth)
        closed.controller.actionButtonDown(at: Point(x: 0, y: 0))
        closed.drag(dx: 0, dy: 10)
        closed.drag(dx: 0, dy: 200)
        closed.controller.actionButtonUp()
        #expect(closed.output.calls.isEmpty)

        let open = Harness(settings: smooth)
        open.spaces.missionControlOpen = true
        open.controller.actionButtonDown(at: Point(x: 0, y: 0))
        open.drag(dx: 0, dy: 10)
        guard case .began(.vertical, let p)? = open.output.calls.first, p > 0 else {
            Issue.record("expected a downward vertical swipe, got \(open.output.calls)")
            return
        }
        open.controller.actionButtonUp()
        guard case .ended? = open.output.calls.last else {
            Issue.record("expected ended, got \(open.output.calls)")
            return
        }
    }

    @Test func verticalDownExitsMissionControlViaHotkeyWhenSmoothUnavailable() {
        let h = Harness(settings: smooth, smoothAvailable: false)
        h.spaces.missionControlOpen = true
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 0, dy: 10)
        h.drag(dx: 0, dy: 60)
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.missionControl])
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
        let h = Harness(settings: .defaults.with { $0.tapAction = .none })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.actionButtonUp()
        h.controller.settings.tapAction = .appExpose
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.appExpose])
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

@Suite struct GestureControllerKeyboardAndFallbackTests {
    let smooth = Settings.defaults.with { $0.switchingStyle = .smooth; $0.pinPointer = true }

    @Test func keyboardStyleStepsAt60And260WithoutDockSwipes() {
        let h = Harness(settings: .defaults.with { $0.switchingStyle = .keyboard; $0.pinPointer = true })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -60, dy: 0)
        #expect(h.output.steps == [.moveSpaceRight])
        h.drag(dx: -200, dy: 0)
        #expect(h.output.steps == [.moveSpaceRight, .moveSpaceRight])
        h.controller.actionButtonUp()
        #expect(h.output.dockCalls.isEmpty)
        #expect(h.pointer.pinned.count == 1)
        #expect(h.pointer.unpinCount == 1)
    }

    @Test func keyboardStyleFollowsNaturalDirectionSetting() {
        let h = Harness(settings: .defaults.with { $0.switchingStyle = .keyboard; $0.naturalDirection = false })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 60, dy: 0)
        #expect(h.output.steps == [.moveSpaceRight])
    }

    @Test func unchangedSpaceAfterASmoothDragIsLeftAlone() {
        let h = Harness(settings: smooth)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -600, dy: 0)
        h.controller.actionButtonUp()
        h.controller.verifySmoothGesture(spaceAfter: h.spaces.space)
        #expect(h.output.steps.isEmpty)
        #expect(h.controller.stickyFallback == false)
        #expect(h.notifier.notices == 0)
    }

    @Test func twoHardErrorsGoStickyWithOneNoticeAndKeyboardAfterwards() {
        let h = Harness(settings: smooth)
        for _ in 0..<2 {
            h.controller.actionButtonDown(at: Point(x: 0, y: 0))
            h.drag(dx: -600, dy: 0)
            h.controller.reportHardError()
            h.controller.actionButtonUp()
        }
        #expect(h.controller.stickyFallback)
        #expect(h.notifier.notices == 1)
        let before = h.output.dockCalls.count
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -80, dy: 0)
        h.controller.actionButtonUp()
        #expect(h.output.dockCalls.count == before)
        #expect(h.output.steps == [.moveSpaceRight, .moveSpaceRight, .moveSpaceRight])
        #expect(h.notifier.notices == 1)
    }

    @Test func aCleanGestureResetsTheHardErrorCount() {
        let h = Harness(settings: smooth)
        func failing() {
            h.controller.actionButtonDown(at: Point(x: 0, y: 0))
            h.drag(dx: -600, dy: 0)
            h.controller.reportHardError()
            h.controller.actionButtonUp()
        }
        func clean() {
            h.controller.actionButtonDown(at: Point(x: 0, y: 0))
            h.drag(dx: -600, dy: 0)
            h.controller.actionButtonUp()
            h.controller.verifySmoothGesture(spaceAfter: h.spaces.space + 1)
        }
        failing()
        clean()
        failing()
        #expect(h.controller.stickyFallback == false)
        #expect(h.notifier.notices == 0)
    }

    @Test func hardErrorMidDragCancelsAndCatchesUp() {
        let h = Harness(settings: smooth)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -600, dy: 0)
        h.controller.reportHardError()
        guard case .cancelled? = h.output.dockCalls.last else {
            Issue.record("expected cancelled, got \(h.output.calls)")
            return
        }
        #expect(h.output.steps == [.moveSpaceRight])
        h.drag(dx: -200, dy: 0)
        #expect(h.output.steps == [.moveSpaceRight, .moveSpaceRight])
        h.controller.actionButtonUp()
        #expect(h.pointer.unpinCount == 1)
    }

    @Test func verifyWithoutAPrecedingSmoothGestureDoesNothing() {
        let h = Harness(settings: smooth)
        h.controller.verifySmoothGesture(spaceAfter: 99)
        #expect(h.output.calls.isEmpty)
        #expect(h.controller.stickyFallback == false)
    }
}

@Suite struct GestureControllerThrowTests {
    let base = Settings.defaults.with { $0.switchingStyle = .smooth }

    @Test func zeroThrowEndsWhereReleasedWithOnlyADirectionNudge() {
        let h = Harness(settings: base.with { $0.throwStrength = 0 })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -600, dy: 0)
        h.drag(dx: 20, dy: 0)   // reversal would cancel with throw on
        h.controller.actionButtonUp()
        let scaler = SwipeProgressScaler(screen: h.spaces.size, spaceCount: h.spaces.count, naturalDirection: false)
        guard case .ended(let progress, let speed)? = h.output.calls.last else {
            Issue.record("expected ended, got \(h.output.calls)")
            return
        }
        #expect(abs(progress - scaler.horizontalProgress(forDelta: -590)) < 1e-9)
        #expect(speed == -ReleaseDecider.minimumNudge)
    }

    @Test func fullThrowReportsRealVelocity() {
        let h = Harness(settings: base.with { $0.throwStrength = 1 })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -40, dy: 0)
        h.controller.actionButtonUp()
        let scaler = SwipeProgressScaler(screen: h.spaces.size, spaceCount: h.spaces.count, naturalDirection: false)
        guard case .ended(let progress, let speed)? = h.output.calls.last else {
            Issue.record("expected ended, got \(h.output.calls)")
            return
        }
        #expect(abs(progress - scaler.horizontalProgress(forDelta: -50)) < 1e-9)
        // 40 points in 9 ms on a 1000 point screen is a fast leftward flick.
        #expect(speed < -1)
    }
}

@Suite struct GestureControllerComboClickTests {
    @Test func leftClickWhileHoldingTakesAnAreaScreenshotAndSwallowsTheTap() {
        let h = Harness(settings: .defaults.with { $0.tapAction = .appExpose })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.comboClick(.left)
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.screenshotSelection])
    }

    @Test func rightClickWhileHoldingOpensScreenshotOptions() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.comboClick(.right)
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.screenshotOptions])
    }

    @Test func comboDuringADragCancelsTheSwipeFirst() {
        let h = Harness(settings: .defaults.with { $0.switchingStyle = .smooth })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -100, dy: 0)
        h.controller.comboClick(.left)
        guard case .cancelled? = h.output.dockCalls.last else {
            Issue.record("expected cancelled, got \(h.output.calls)")
            return
        }
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.screenshotSelection])
        #expect(h.output.dockCalls.count == 2)
    }

    @Test func comboWithoutTheActionButtonHeldIsIgnored() {
        let h = Harness()
        h.controller.comboClick(.left)
        #expect(h.output.calls.isEmpty)
    }

    @Test func onlyTheFirstComboInAHoldFires() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.controller.comboClick(.left)
        h.controller.comboClick(.right)
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.screenshotSelection])
    }
}
