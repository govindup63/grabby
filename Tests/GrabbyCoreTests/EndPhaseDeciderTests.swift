import Testing
@testable import GrabbyCore

@Suite struct ReleaseDeciderTests {
    @Test func velocityScaledByThrow() {
        #expect(abs(ReleaseDecider.exitSpeed(velocity: 4.0, progress: 0.3, throwStrength: 1) - 4.0) < 1e-12)
        #expect(abs(ReleaseDecider.exitSpeed(velocity: 4.0, progress: 0.3, throwStrength: 0.5) - 2.0) < 1e-12)
    }

    @Test func zeroThrowSendsOnlyADirectionNudgeMatchingPosition() {
        #expect(ReleaseDecider.exitSpeed(velocity: 4.0, progress: 0.3, throwStrength: 0) == ReleaseDecider.minimumNudge)
        #expect(ReleaseDecider.exitSpeed(velocity: 4.0, progress: -0.3, throwStrength: 0) == -ReleaseDecider.minimumNudge)
        #expect(ReleaseDecider.exitSpeed(velocity: 4.0, progress: 0, throwStrength: 0) == 0)
    }

    @Test func tinyVelocityBecomesANudgeInThePositionDirection() {
        #expect(ReleaseDecider.exitSpeed(velocity: -0.001, progress: 0.6, throwStrength: 1) == ReleaseDecider.minimumNudge)
    }

    @Test func committedWhenPastHalfAtRelease() {
        #expect(ReleaseDecider.looksCommitted(progress: 0.5))
        #expect(ReleaseDecider.looksCommitted(progress: -0.7))
        #expect(!ReleaseDecider.looksCommitted(progress: 0.49))
    }
}

@Suite struct CoalescerVelocityTests {
    @Test func steadyMotionGivesProgressPerSecond() {
        let clock = FakeClock()
        var c = EventCoalescer(clock: clock)
        _ = c.began(progress: 0)
        for _ in 0..<10 {
            clock.advance(.milliseconds(8))
            _ = c.changed(delta: 0.01)
        }
        // 0.1 progress over 80 ms = 1.25 per second
        #expect(abs(c.velocity(now: clock.now()) - 1.25) < 0.05)
    }

    @Test func velocityIsZeroAfterHoldingStill() {
        let clock = FakeClock()
        var c = EventCoalescer(clock: clock)
        _ = c.began(progress: 0)
        clock.advance(.milliseconds(8))
        _ = c.changed(delta: 0.05)
        clock.advance(.milliseconds(300))
        #expect(abs(c.velocity(now: clock.now())) < 1e-9)
    }

    @Test func velocityFollowsTheMostRecentDirection() {
        let clock = FakeClock()
        var c = EventCoalescer(clock: clock)
        _ = c.began(progress: 0)
        for _ in 0..<10 { clock.advance(.milliseconds(8)); _ = c.changed(delta: 0.02) }
        for _ in 0..<10 { clock.advance(.milliseconds(8)); _ = c.changed(delta: -0.01) }
        #expect(c.velocity(now: clock.now()) < 0)
    }
}
