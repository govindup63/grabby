import Foundation
@testable import GrabbyCore

final class FakeClock: GrabbyClock, @unchecked Sendable {
    var current: Duration = .zero
    func now() -> Duration { current }
    func advance(_ d: Duration) { current += d }
}

final class FakeOutput: GestureOutput {
    enum Call: Equatable {
        case began(Axis, Double)
        case changed(Double)
        case ended(Double, Double)
        case cancelled(Double, Double)
        case step(StepCommand)
    }
    var calls: [Call] = []
    var steps: [StepCommand] { calls.compactMap { if case .step(let s) = $0 { return s } else { return nil } } }
    var dockCalls: [Call] { calls.filter { if case .step = $0 { return false } else { return true } } }

    func dockSwipeBegan(axis: Axis, progress: Double) { calls.append(.began(axis, progress)) }
    func dockSwipeChanged(progress: Double) { calls.append(.changed(progress)) }
    func dockSwipeEnded(progress: Double, exitSpeed: Double) { calls.append(.ended(progress, exitSpeed)) }
    func dockSwipeCancelled(progress: Double, exitSpeed: Double) { calls.append(.cancelled(progress, exitSpeed)) }
    func perform(_ step: StepCommand) { calls.append(.step(step)) }
}

final class FakeSpaces: SpaceReader {
    var space: UInt64 = 1
    var count = 2
    var size = Size(width: 1000, height: 500)
    func activeSpace() -> UInt64 { space }
    func spaceCount(onDisplayUnderPointer: Bool) -> Int { count }
    func screenSize() -> Size { size }
}

final class FakePointer: PointerPin {
    var pinned: [Point] = []
    var unpinCount = 0
    func pin(at origin: Point) { pinned.append(origin) }
    func unpin() { unpinCount += 1 }
}

final class FakeNotifier: UserNotifier {
    var notices = 0
    func showFallbackNotice() { notices += 1 }
}

struct Harness {
    let clock = FakeClock()
    let output = FakeOutput()
    let spaces = FakeSpaces()
    let pointer = FakePointer()
    let notifier = FakeNotifier()
    let controller: GestureController

    init(settings: Settings = .defaults, smoothAvailable: Bool = true) {
        controller = GestureController(settings: settings, smoothAvailable: smoothAvailable, clock: clock,
                                       output: output, spaces: spaces, pointer: pointer, notifier: notifier)
    }

    /// Moves the pointer and advances the clock past the coalescing interval.
    func drag(dx: Double, dy: Double) {
        controller.pointerMoved(dx: dx, dy: dy)
        clock.advance(.milliseconds(9))
    }
}

extension Settings {
    func with(_ edit: (inout Settings) -> Void) -> Settings {
        var copy = self
        edit(&copy)
        return copy
    }
}
