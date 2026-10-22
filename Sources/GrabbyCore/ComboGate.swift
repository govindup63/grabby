import Foundation

/// Answers, synchronously and from any thread, whether a left or right click should be taken as a
/// hold-plus-click combo. Open while the action button is held; the first click consumes it.
/// Lets the click tap decide instantly without waiting on the gesture queue.
public final class ComboGate: @unchecked Sendable {
    private let lock = NSLock()
    private var armed = false

    public init() {}

    public func open() {
        lock.withLock { armed = true }
    }

    public func close() {
        lock.withLock { armed = false }
    }

    /// True exactly once per open.
    public func tryConsume() -> Bool {
        lock.withLock {
            guard armed else { return false }
            armed = false
            return true
        }
    }
}
