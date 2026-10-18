import Testing
@testable import GrabbyCore

@Suite struct EndPhaseDeciderTests {
    @Test func sameSignEnds() {
        #expect(EndPhaseDecider.phase(lastDelta: 0.1, originOffset: 0.8, throwStrength: 1) == .ended)
        #expect(EndPhaseDecider.phase(lastDelta: -0.1, originOffset: -0.8, throwStrength: 1) == .ended)
    }

    @Test func oppositeSignCancelsWhenThrowIsOn() {
        #expect(EndPhaseDecider.phase(lastDelta: -0.1, originOffset: 0.8, throwStrength: 0.5) == .cancelled)
        #expect(EndPhaseDecider.phase(lastDelta: 0.1, originOffset: -0.8, throwStrength: 0.5) == .cancelled)
    }

    @Test func zeroThrowNeverCancelsSoPositionDecides() {
        #expect(EndPhaseDecider.phase(lastDelta: -0.1, originOffset: 0.8, throwStrength: 0) == .ended)
    }

    @Test func zeroLastDeltaEnds() {
        #expect(EndPhaseDecider.phase(lastDelta: 0, originOffset: 0.5, throwStrength: 1) == .ended)
    }

    @Test func exitSpeedScalesWithThrow() {
        #expect(abs(EndPhaseDecider.exitSpeed(lastDelta: 0.02, throwStrength: 1) - 2.0) < 1e-12)
        #expect(abs(EndPhaseDecider.exitSpeed(lastDelta: 0.02, throwStrength: 0.5) - 1.0) < 1e-12)
        #expect(EndPhaseDecider.exitSpeed(lastDelta: 0.02, throwStrength: 0) == 0)
    }
}

@Suite struct ThrowResolverTests {
    let oneSpace = 1.5

    @Test func zeroThrowLeavesProgressAlone() {
        #expect(ThrowResolver.finalProgress(originOffset: 0.4, lastDelta: 0.05, throwStrength: 0, oneSpace: oneSpace) == 0.4)
    }

    @Test func flickAddsInTheDirectionOfTheLastDelta() {
        let forward = ThrowResolver.finalProgress(originOffset: 0.4, lastDelta: 0.01, throwStrength: 1, oneSpace: oneSpace)
        #expect(forward > 0.4)
        let back = ThrowResolver.finalProgress(originOffset: 0.4, lastDelta: -0.01, throwStrength: 1, oneSpace: oneSpace)
        #expect(back < 0.4)
    }

    @Test func throwIsCappedAtSixtyPercentOfOneSpace() {
        let huge = ThrowResolver.finalProgress(originOffset: 0, lastDelta: 5, throwStrength: 1, oneSpace: oneSpace)
        #expect(abs(huge - 0.6 * oneSpace) < 1e-9)
    }

    @Test func halfStrengthThrowsHalfAsFar() {
        let full = ThrowResolver.finalProgress(originOffset: 0, lastDelta: 0.01, throwStrength: 1, oneSpace: oneSpace)
        let half = ThrowResolver.finalProgress(originOffset: 0, lastDelta: 0.01, throwStrength: 0.5, oneSpace: oneSpace)
        #expect(abs(half - full / 2) < 1e-9)
    }
}
