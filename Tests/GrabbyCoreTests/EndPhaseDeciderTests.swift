import Testing
@testable import GrabbyCore

@Suite struct EndPhaseDeciderTests {
    @Test func sameSignEnds() {
        #expect(EndPhaseDecider.phase(lastDelta: 0.1, originOffset: 0.8) == .ended)
        #expect(EndPhaseDecider.phase(lastDelta: -0.1, originOffset: -0.8) == .ended)
    }

    @Test func oppositeSignCancels() {
        #expect(EndPhaseDecider.phase(lastDelta: -0.1, originOffset: 0.8) == .cancelled)
        #expect(EndPhaseDecider.phase(lastDelta: 0.1, originOffset: -0.8) == .cancelled)
    }

    @Test func zeroLastDeltaEnds() {
        #expect(EndPhaseDecider.phase(lastDelta: 0, originOffset: 0.5) == .ended)
    }

    @Test func exitSpeedIsLastDeltaTimesHundred() {
        #expect(abs(EndPhaseDecider.exitSpeed(lastDelta: 0.02) - 2.0) < 1e-12)
    }
}
