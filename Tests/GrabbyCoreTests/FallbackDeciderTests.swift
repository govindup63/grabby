import Testing
@testable import GrabbyCore

@Suite struct FallbackDeciderTests {
    /// `distance` here is Dock progress: 1.0 is one desktop, 0.5 commits.
    func obs(axis: Axis = .horizontal, distance: Double, changed: Bool, hardError: Bool = false,
             failures: Int = 0, natural: Bool = true, down: DragDownAction = .appExpose) -> FallbackObservation {
        FallbackObservation(axis: axis, progress: distance / 100, spaceBefore: 1, spaceAfter: changed ? 2 : 1,
                            hardError: hardError, consecutiveFailures: failures,
                            naturalDirection: natural, dragDownAction: down)
    }

    @Test func committedDragWithUnchangedSpaceIsAFailureWithCatchUp() {
        let v = FallbackDecider.decide(obs(distance: -80, changed: false))
        #expect(v.catchUpStep == .moveSpaceRight)
        #expect(v.failureCount == 1)
        #expect(v.becameSticky == false)
    }

    @Test func secondConsecutiveFailureBecomesSticky() {
        let v = FallbackDecider.decide(obs(distance: -80, changed: false, failures: 1))
        #expect(v.catchUpStep == .moveSpaceRight)
        #expect(v.failureCount == 2)
        #expect(v.becameSticky)
    }

    @Test func changedSpaceIsASuccessAndResets() {
        let v = FallbackDecider.decide(obs(distance: -80, changed: true, failures: 1))
        #expect(v.catchUpStep == nil)
        #expect(v.failureCount == 0)
        #expect(v.becameSticky == false)
    }

    @Test func subThresholdDragIsNeverAFailure() {
        let v = FallbackDecider.decide(obs(distance: -40, changed: false, failures: 1))
        #expect(v.catchUpStep == nil)
        #expect(v.failureCount == 1)
        #expect(v.becameSticky == false)
    }

    @Test func hardErrorAlwaysCountsAndCatchesUp() {
        let v = FallbackDecider.decide(obs(distance: -80, changed: true, hardError: true))
        #expect(v.catchUpStep == .moveSpaceRight)
        #expect(v.failureCount == 1)
    }

    @Test func verticalWithoutHardErrorIsASuccess() {
        let v = FallbackDecider.decide(obs(axis: .vertical, distance: -80, changed: false, failures: 1))
        #expect(v.catchUpStep == nil)
        #expect(v.failureCount == 0)
    }

    @Test func verticalHardErrorCatchesUpWithTheRightAction() {
        #expect(FallbackDecider.decide(obs(axis: .vertical, distance: -80, changed: false, hardError: true)).catchUpStep == .missionControl)
        #expect(FallbackDecider.decide(obs(axis: .vertical, distance: 80, changed: false, hardError: true, down: .showDesktop)).catchUpStep == .showDesktop)
        #expect(FallbackDecider.decide(obs(axis: .vertical, distance: 80, changed: false, hardError: true, down: .none)).catchUpStep == nil)
    }

    @Test func directionFollowsNaturalDirection() {
        #expect(FallbackDecider.decide(obs(distance: 80, changed: false)).catchUpStep == .moveSpaceLeft)
        #expect(FallbackDecider.decide(obs(distance: 80, changed: false, natural: false)).catchUpStep == .moveSpaceRight)
        #expect(FallbackDecider.decide(obs(distance: -80, changed: false, natural: false)).catchUpStep == .moveSpaceLeft)
    }
}
