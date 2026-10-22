import Testing
@testable import GrabbyCore

@Suite struct GestureControllerTapTests {
    @Test func tapDoesNothingByDefault() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 10, y: 10))
        h.controller.actionButtonUp()
        #expect(h.output.calls.isEmpty)
    }

    @Test(arguments: [(TapAction.missionControl, [StepCommand.missionControl]),
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

    @Test func changingTapActionAtRuntimeAffectsNextTap() {
        let h = Harness()
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
}

@Suite struct GestureControllerSlideTests {
    @Test func horizontalDragBeginsChangesEnds() {
        let h = Harness(settings: .defaults.with { $0.throwStrength = 0 })
        h.controller.actionButtonDown(at: Point(x: 100, y: 100))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -300, dy: 0)
        h.drag(dx: -300, dy: 0)
        h.controller.actionButtonUp()

        let scaler = SwipeProgressScaler(screen: h.spaces.size, spaceCount: h.spaces.count, naturalDirection: false)
        #expect(h.output.calls.first == .began(.horizontal, scaler.horizontalProgress(forDelta: -10)))
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

    @Test func updateRateMatchesTheDisplayUnderThePointer() {
        let h = Harness()
        h.spaces.refresh = .milliseconds(16)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -10, dy: 0)          // began, clock +9 ms
        h.drag(dx: -10, dy: 0)          // 9 ms since began: held on a 60 Hz display
        h.drag(dx: -10, dy: 0)          // 18 ms: sent
        let changes = h.output.calls.filter { if case .changed = $0 { return true } else { return false } }
        #expect(changes.count == 1)
    }

    @Test func legacyFormatScalesAndSignsLikeMacMouseFix() {
        let h = Harness(format: .legacyFields)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -10, dy: 0)
        let legacy = SwipeProgressScaler(screen: h.spaces.size, spaceCount: h.spaces.count, naturalDirection: false, format: .legacyFields)
        #expect(h.output.calls.first == .began(.horizontal, legacy.horizontalProgress(forDelta: -10)))
        guard case .began(_, let p)? = h.output.calls.first else { return }
        #expect(p > 0)   // Mac Mouse Fix's sign: leftward motion is positive on the legacy path
    }

    @Test func shortDragStillEndsAndLetsTheDockSlideBack() {
        let h = Harness(settings: .defaults.with { $0.throwStrength = 0 })
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
        let h = Harness(settings: .defaults.with { $0.throwStrength = 1 })
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

    @Test func fullThrowReportsRealVelocity() {
        let h = Harness(settings: .defaults.with { $0.throwStrength = 1 })
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -10, dy: 0)
        h.drag(dx: -40, dy: 0)
        h.controller.actionButtonUp()
        guard case .ended(_, let speed)? = h.output.calls.last else {
            Issue.record("expected ended, got \(h.output.calls)")
            return
        }
        #expect(speed < -1)
    }

    @Test func userCancelSendsCancelled() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -40, dy: 0)
        h.controller.cancelGesture()
        guard case .cancelled? = h.output.calls.last else {
            Issue.record("expected cancelled, got \(h.output.calls)")
            return
        }
        h.controller.actionButtonUp()
        #expect(h.output.calls.count == 2)
    }

    @Test func naturalDirectionOverrideOnlyFlipsWhenItDiffersFromTheSystem() {
        let same = Harness(settings: .defaults.with { $0.naturalDirection = true })
        same.controller.systemNaturalDirection = true
        same.controller.actionButtonDown(at: Point(x: 0, y: 0))
        same.drag(dx: -10, dy: 0)
        guard case .began(_, let p1)? = same.output.calls.first else { Issue.record("no began"); return }
        #expect(p1 < 0)

        let flipped = Harness(settings: .defaults.with { $0.naturalDirection = false })
        flipped.controller.systemNaturalDirection = true
        flipped.controller.actionButtonDown(at: Point(x: 0, y: 0))
        flipped.drag(dx: -10, dy: 0)
        guard case .began(_, let p2)? = flipped.output.calls.first else { Issue.record("no began"); return }
        #expect(p2 > 0)
    }

    @Test func verticalUpUsesVerticalDockSwipe() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 0, dy: -10)
        guard case .began(.vertical, let p)? = h.output.calls.first, p > 0 else {
            Issue.record("expected upward vertical began (positive), got \(h.output.calls)")
            return
        }
        h.controller.actionButtonUp()
        #expect(h.output.steps.isEmpty)
    }

    @Test func verticalDownExitsMissionControlOnlyWhenItIsOpen() {
        let closed = Harness()
        closed.controller.actionButtonDown(at: Point(x: 0, y: 0))
        closed.drag(dx: 0, dy: 10)
        closed.drag(dx: 0, dy: 200)
        closed.controller.actionButtonUp()
        #expect(closed.output.calls.isEmpty)

        let open = Harness()
        open.spaces.missionControlOpen = true
        open.controller.actionButtonDown(at: Point(x: 0, y: 0))
        open.drag(dx: 0, dy: 10)
        guard case .began(.vertical, let p)? = open.output.calls.first, p < 0 else {
            Issue.record("expected a downward vertical swipe (negative), got \(open.output.calls)")
            return
        }
        open.controller.actionButtonUp()
        guard case .ended? = open.output.calls.last else {
            Issue.record("expected ended, got \(open.output.calls)")
            return
        }
    }
}

@Suite struct GestureControllerKeyboardFallbackTests {
    @Test func withoutTheSmoothEngineHorizontalDragsStep() {
        let h = Harness(smoothAvailable: false)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -60, dy: 0)
        #expect(h.output.steps == [.moveSpaceRight])
        h.drag(dx: -200, dy: 0)
        #expect(h.output.steps == [.moveSpaceRight, .moveSpaceRight])
        h.controller.actionButtonUp()
        #expect(h.output.dockCalls.isEmpty)
    }

    @Test func keyboardStepsFollowNaturalDirection() {
        let h = Harness(settings: .defaults.with { $0.naturalDirection = false }, smoothAvailable: false)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 60, dy: 0)
        #expect(h.output.steps == [.moveSpaceRight])
    }

    @Test func withoutTheSmoothEngineVerticalUpOpensMissionControl() {
        let h = Harness(smoothAvailable: false)
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 0, dy: -10)
        h.drag(dx: 0, dy: -60)
        h.controller.actionButtonUp()
        #expect(h.output.dockCalls.isEmpty)
        #expect(h.output.steps == [.missionControl])
    }

    @Test func withoutTheSmoothEngineVerticalDownClosesMissionControlViaHotkey() {
        let h = Harness(smoothAvailable: false)
        h.spaces.missionControlOpen = true
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: 0, dy: 10)
        h.drag(dx: 0, dy: 60)
        h.controller.actionButtonUp()
        #expect(h.output.steps == [.missionControl])
    }

    @Test func unchangedSpaceAfterASmoothDragIsLeftAlone() {
        let h = Harness()
        h.controller.actionButtonDown(at: Point(x: 0, y: 0))
        h.drag(dx: -600, dy: 0)
        h.controller.actionButtonUp()
        h.controller.verifySmoothGesture(spaceAfter: h.spaces.space)
        #expect(h.output.steps.isEmpty)
        #expect(h.controller.stickyFallback == false)
        #expect(h.notifier.notices == 0)
    }

    @Test func twoHardErrorsGoStickyWithOneNoticeAndKeyboardAfterwards() {
        let h = Harness()
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
        let h = Harness()
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
        let h = Harness()
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
    }

    @Test func verifyWithoutAPrecedingSmoothGestureDoesNothing() {
        let h = Harness()
        h.controller.verifySmoothGesture(spaceAfter: 99)
        #expect(h.output.calls.isEmpty)
        #expect(h.controller.stickyFallback == false)
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
        let h = Harness()
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
