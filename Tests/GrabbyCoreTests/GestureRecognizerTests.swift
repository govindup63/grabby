import Testing
@testable import GrabbyCore

@Suite struct GestureRecognizerTests {
    @Test func buttonDownEmitsNothing() {
        var r = GestureRecognizer()
        #expect(r.buttonDown().isEmpty)
    }

    @Test func movesUnderThresholdThenUpIsATap() {
        var r = GestureRecognizer()
        _ = r.buttonDown()
        #expect(r.move(dx: 3, dy: 2).isEmpty)
        #expect(r.move(dx: 2, dy: 2).isEmpty)
        #expect(r.buttonUp() == [.tap])
        #expect(r.isDragging == false)
    }

    @Test func exactlyThresholdDoesNotLock() {
        var r = GestureRecognizer()
        _ = r.buttonDown()
        #expect(r.move(dx: 7, dy: 0).isEmpty)
        #expect(r.move(dx: 1, dy: 0) == [.dragBegan(.horizontal)])
    }

    @Test func largerComponentPicksAxis() {
        var h = GestureRecognizer()
        _ = h.buttonDown()
        #expect(h.move(dx: 8, dy: 1) == [.dragBegan(.horizontal)])
        #expect(h.axis == .horizontal)

        var v = GestureRecognizer()
        _ = v.buttonDown()
        #expect(v.move(dx: 1, dy: 8) == [.dragBegan(.vertical)])
        #expect(v.axis == .vertical)
    }

    @Test func tieGoesHorizontal() {
        var r = GestureRecognizer()
        _ = r.buttonDown()
        #expect(r.move(dx: 8, dy: 8) == [.dragBegan(.horizontal)])
    }

    @Test func afterLockOnlyLockedAxisIsReported() {
        var r = GestureRecognizer()
        _ = r.buttonDown()
        _ = r.move(dx: 8, dy: 0)
        #expect(r.move(dx: 3, dy: 5) == [.dragChanged(3)])
        #expect(r.move(dx: -2, dy: 50) == [.dragChanged(-2)])
    }

    @Test func distanceIsSignedSumAlongAxis() {
        var r = GestureRecognizer()
        _ = r.buttonDown()
        _ = r.move(dx: 8, dy: 0)
        #expect(r.distance == 8)
        _ = r.move(dx: -3, dy: 9)
        #expect(r.distance == 5)
    }

    @Test func buttonUpWhileDraggingEnds() {
        var r = GestureRecognizer()
        _ = r.buttonDown()
        _ = r.move(dx: 8, dy: 0)
        #expect(r.isDragging)
        #expect(r.buttonUp() == [.dragEnded])
        #expect(r.isDragging == false)
        #expect(r.axis == nil)
    }

    @Test func cancelWhileDraggingCancels() {
        var r = GestureRecognizer()
        _ = r.buttonDown()
        _ = r.move(dx: 0, dy: 9)
        #expect(r.cancel() == [.dragCancelled])
    }

    @Test func cancelWhileIdleOrPressedEmitsNothing() {
        var idle = GestureRecognizer()
        #expect(idle.cancel().isEmpty)
        var pressed = GestureRecognizer()
        _ = pressed.buttonDown()
        _ = pressed.move(dx: 1, dy: 1)
        #expect(pressed.cancel().isEmpty)
    }
}
