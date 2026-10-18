import Testing
@testable import GrabbyCore

@Suite struct EventCoalescerTests {
    @Test func beganResetsAndReturnsProgress() {
        let clock = FakeClock()
        var c = EventCoalescer(clock: clock)
        #expect(c.began(progress: 0.1) == 0.1)
        #expect(c.originOffset == 0.1)
    }

    @Test func nineteenChangesInsideEightMillisecondsAreHeldThenSentAsOne() {
        let clock = FakeClock()
        var c = EventCoalescer(clock: clock)
        _ = c.began(progress: 0)
        var held = 0
        for _ in 0..<19 {
            clock.advance(.microseconds(400))
            if c.changed(delta: 0.01) == nil { held += 1 }
        }
        #expect(held == 19)
        clock.advance(.milliseconds(2))
        let sent = c.changed(delta: 0.01)
        #expect(sent != nil)
        #expect(abs((sent ?? 0) - 0.20) < 1e-9)
    }

    @Test func noMotionIsLost() {
        let clock = FakeClock()
        var c = EventCoalescer(clock: clock)
        _ = c.began(progress: 0)
        var total = 0.0
        for i in 0..<50 {
            clock.advance(.milliseconds(i % 3 == 0 ? 9 : 1))
            _ = c.changed(delta: 0.005)
            total += 0.005
        }
        #expect(abs(c.flushForEnd() - total) < 1e-9)
        #expect(abs(c.originOffset - total) < 1e-9)
    }

    @Test func lastDeltaTracksMostRecentNonZero() {
        let clock = FakeClock()
        var c = EventCoalescer(clock: clock)
        _ = c.began(progress: 0)
        clock.advance(.milliseconds(9))
        _ = c.changed(delta: 0.03)
        clock.advance(.milliseconds(9))
        _ = c.changed(delta: -0.02)
        #expect(c.lastDelta == -0.02)
        clock.advance(.milliseconds(9))
        #expect(c.changed(delta: 0) == nil)
        #expect(c.lastDelta == -0.02)
    }
}
