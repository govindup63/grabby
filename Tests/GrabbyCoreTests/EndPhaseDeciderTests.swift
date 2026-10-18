import Testing
@testable import GrabbyCore

@Suite struct EndPhaseDeciderTests {
    let oneSpace = 1.5

    @Test func pastHalfwayCommits() {
        #expect(EndPhaseDecider.phase(lastDelta: 0.01, originOffset: 0.8 * oneSpace, throwStrength: 0, oneSpace: oneSpace) == .ended)
        #expect(EndPhaseDecider.phase(lastDelta: -0.01, originOffset: -0.8 * oneSpace, throwStrength: 0, oneSpace: oneSpace) == .ended)
        #expect(EndPhaseDecider.phase(lastDelta: 0, originOffset: 0.5 * oneSpace, throwStrength: 0, oneSpace: oneSpace) == .ended)
    }

    @Test func shortOfHalfwaySnapsBack() {
        #expect(EndPhaseDecider.phase(lastDelta: 0.01, originOffset: 0.1 * oneSpace, throwStrength: 0, oneSpace: oneSpace) == .cancelled)
        #expect(EndPhaseDecider.phase(lastDelta: 0.01, originOffset: 0.49 * oneSpace, throwStrength: 0, oneSpace: oneSpace) == .cancelled)
        #expect(EndPhaseDecider.phase(lastDelta: 0, originOffset: 0, throwStrength: 1, oneSpace: oneSpace) == .cancelled)
    }

    @Test func zeroThrowIgnoresReversalPositionDecides() {
        #expect(EndPhaseDecider.phase(lastDelta: -0.05, originOffset: 0.8 * oneSpace, throwStrength: 0, oneSpace: oneSpace) == .ended)
    }

    @Test func withThrowAReverseFlickSnapsBackEvenPastHalfway() {
        #expect(EndPhaseDecider.phase(lastDelta: -0.05, originOffset: 0.8 * oneSpace, throwStrength: 0.5, oneSpace: oneSpace) == .cancelled)
    }

    @Test func withThrowAForwardFlickCommitsShortOfHalfway() {
        // ThrowResolver carries up to 60% of a space at full strength; 0.1 + 0.6 > 0.5.
        #expect(EndPhaseDecider.phase(lastDelta: 0.05, originOffset: 0.1 * oneSpace, throwStrength: 1, oneSpace: oneSpace) == .ended)
        // A tiny nudge is not a flick.
        #expect(EndPhaseDecider.phase(lastDelta: 0.0005, originOffset: 0.1 * oneSpace, throwStrength: 1, oneSpace: oneSpace) == .cancelled)
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
