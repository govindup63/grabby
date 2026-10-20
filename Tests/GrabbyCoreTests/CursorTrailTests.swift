import Testing
@testable import GrabbyCore

@Suite struct CursorTrailTests {
    @Test func startsEmpty() {
        var t = CursorTrail()
        #expect(t.isEmpty)
        #expect(t.segments(now: .zero).isEmpty)
    }

    @Test func consecutivePointsBecomeSegmentsNewestLast() {
        var t = CursorTrail()
        t.append(Point(x: 0, y: 0), at: .milliseconds(0))
        t.append(Point(x: 10, y: 0), at: .milliseconds(10))
        t.append(Point(x: 20, y: 5), at: .milliseconds(20))
        let s = t.segments(now: .milliseconds(20))
        #expect(s.count == 2)
        #expect(s[0].from == Point(x: 0, y: 0) && s[0].to == Point(x: 10, y: 0))
        #expect(s[1].from == Point(x: 10, y: 0) && s[1].to == Point(x: 20, y: 5))
    }

    @Test func alphaFadesWithAgeAndIsFullForTheNewest() {
        var t = CursorTrail()
        t.append(Point(x: 0, y: 0), at: .zero)
        t.append(Point(x: 10, y: 0), at: .milliseconds(200))
        t.append(Point(x: 20, y: 0), at: .milliseconds(400))
        let s = t.segments(now: .milliseconds(400))
        #expect(s.count == 2)
        #expect(abs(s[1].alpha - 1.0) < 1e-9)
        #expect(s[0].alpha < s[1].alpha)
        #expect(s[0].alpha > 0)
    }

    @Test func pointsOlderThanTheLifetimeArePruned() {
        var t = CursorTrail()
        t.append(Point(x: 0, y: 0), at: .zero)
        t.append(Point(x: 1, y: 0), at: .milliseconds(100))
        t.append(Point(x: 2, y: 0), at: .milliseconds(900))
        let s = t.segments(now: .milliseconds(900))
        #expect(s.count == 0)   // the only survivor is the newest point; no partner to draw to
        #expect(!t.isEmpty)
        #expect(t.segments(now: .milliseconds(900) + CursorTrail.lifetime + .milliseconds(1)).isEmpty)
        #expect(t.isEmpty)
    }

    @Test func tinyMovesAreNotStoredSoAStillHandDoesNotPileUpPoints() {
        var t = CursorTrail()
        for i in 0..<50 {
            t.append(Point(x: Double(i) * 0.1, y: 0), at: .milliseconds(Int64(i)))
        }
        #expect(t.segments(now: .milliseconds(50)).count <= 2)
    }

    @Test func pointCountIsCapped() {
        var t = CursorTrail()
        for i in 0..<500 {
            t.append(Point(x: Double(i) * 5, y: 0), at: .milliseconds(Int64(i)))
        }
        #expect(t.segments(now: .milliseconds(500)).count <= CursorTrail.maxPoints - 1)
    }

    @Test func clearEmptiesEverything() {
        var t = CursorTrail()
        t.append(Point(x: 0, y: 0), at: .zero)
        t.append(Point(x: 9, y: 9), at: .milliseconds(5))
        t.clear()
        #expect(t.isEmpty)
    }
}
