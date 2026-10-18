import Testing
@testable import GrabbyCore

@Suite struct DiscreteStepperTests {
    @Test func horizontalStepsAt60Then200Each() {
        var s = DiscreteStepper(axis: .horizontal, dragDownAction: .appExpose, naturalDirection: false)
        #expect(s.move(delta: 30).isEmpty)
        #expect(s.move(delta: 29).isEmpty)
        #expect(s.move(delta: 1) == [.moveSpaceRight])
        #expect(s.move(delta: 199).isEmpty)
        #expect(s.move(delta: 1) == [.moveSpaceRight])
        #expect(s.move(delta: 200) == [.moveSpaceRight])
    }

    @Test func oneBigMoveCanFireSeveralSteps() {
        var s = DiscreteStepper(axis: .horizontal, dragDownAction: .appExpose, naturalDirection: false)
        #expect(s.move(delta: -260) == [.moveSpaceLeft, .moveSpaceLeft])
    }

    @Test func draggingBackDoesNotRetract() {
        var s = DiscreteStepper(axis: .horizontal, dragDownAction: .appExpose, naturalDirection: false)
        #expect(s.move(delta: 100) == [.moveSpaceRight])
        #expect(s.move(delta: -100).isEmpty)
    }

    @Test func crossingOriginResetsAndCountsTheOtherWay() {
        var s = DiscreteStepper(axis: .horizontal, dragDownAction: .appExpose, naturalDirection: false)
        _ = s.move(delta: 100)
        _ = s.move(delta: -100)
        #expect(s.move(delta: -59).isEmpty)
        #expect(s.move(delta: -1) == [.moveSpaceLeft])
    }

    @Test func verticalUpFiresMissionControlOnce() {
        var s = DiscreteStepper(axis: .vertical, dragDownAction: .appExpose, naturalDirection: false)
        #expect(s.move(delta: -59).isEmpty)
        #expect(s.move(delta: -1) == [.missionControl])
        #expect(s.move(delta: -300).isEmpty)
        #expect(s.move(delta: 400).isEmpty)
    }

    @Test(arguments: [(DragDownAction.appExpose, [StepCommand.appExpose]),
                      (DragDownAction.showDesktop, [StepCommand.showDesktop]),
                      (DragDownAction.none, [])])
    func verticalDownFiresConfiguredActionOnce(action: DragDownAction, expected: [StepCommand]) {
        var s = DiscreteStepper(axis: .vertical, dragDownAction: action, naturalDirection: false)
        #expect(s.move(delta: 59).isEmpty)
        #expect(s.move(delta: 1) == expected)
        #expect(s.move(delta: 300).isEmpty)
    }

    @Test func naturalDirectionFlipsHorizontalSteps() {
        var s = DiscreteStepper(axis: .horizontal, dragDownAction: .appExpose, naturalDirection: true)
        #expect(s.move(delta: -60) == [.moveSpaceRight])
        var t = DiscreteStepper(axis: .horizontal, dragDownAction: .appExpose, naturalDirection: true)
        #expect(t.move(delta: 60) == [.moveSpaceLeft])
    }
}
