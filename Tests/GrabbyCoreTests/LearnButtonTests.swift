import Testing
@testable import GrabbyCore

@Suite struct LearnButtonTests {
    @Test(arguments: [0, 1]) func leftAndRightAreRejected(button: Int) {
        var s = LearnButtonSession.start(at: .zero)
        guard case .rejected(let reason) = s.buttonPressed(number: button, at: .seconds(1)) else {
            Issue.record("expected rejection for button \(button)")
            return
        }
        #expect(reason.lowercased().contains(button == 0 ? "left" : "right"))
        #expect(s.tick(now: .seconds(2)) == .waiting)
    }

    @Test(arguments: [2, 4, 31]) func otherButtonsAreLearned(button: Int) {
        var s = LearnButtonSession.start(at: .zero)
        #expect(s.buttonPressed(number: button, at: .seconds(1)) == .learned(button))
    }

    @Test func outOfRangeButtonIsRejected() {
        var s = LearnButtonSession.start(at: .zero)
        guard case .rejected = s.buttonPressed(number: 32, at: .seconds(1)) else {
            Issue.record("expected rejection for button 32")
            return
        }
    }

    @Test func ticksBeforeTenSecondsWait() {
        var s = LearnButtonSession.start(at: .seconds(5))
        #expect(s.tick(now: .seconds(5)) == .waiting)
        #expect(s.tick(now: .seconds(14)) == .waiting)
        #expect(s.tick(now: .milliseconds(14_999)) == .waiting)
    }

    @Test func tenSecondsWithoutAPressTimesOut() {
        var s = LearnButtonSession.start(at: .seconds(5))
        #expect(s.tick(now: .seconds(15)) == .timedOut)
        #expect(s.tick(now: .seconds(16)) == .finished)
    }

    @Test func afterLearningEverythingIsFinished() {
        var s = LearnButtonSession.start(at: .zero)
        _ = s.buttonPressed(number: 3, at: .seconds(1))
        #expect(s.buttonPressed(number: 4, at: .seconds(2)) == .finished)
        #expect(s.tick(now: .seconds(30)) == .finished)
    }
}
