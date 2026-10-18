import Foundation

/// Collapses "changed" progress updates to one per 8 ms (the trackpad cadence) without losing motion.
public struct EventCoalescer {
    public static let interval: Duration = .milliseconds(8)

    private let clock: any GrabbyClock
    private var lastSentAt: Duration = .zero
    public private(set) var originOffset: Double = 0
    public private(set) var lastDelta: Double = 0

    public init(clock: any GrabbyClock) {
        self.clock = clock
    }

    public mutating func began(progress: Double) -> Double {
        originOffset = progress
        lastDelta = progress
        lastSentAt = clock.now()
        return progress
    }

    /// Returns the accumulated origin offset when it is time to send, nil when held back.
    public mutating func changed(delta: Double) -> Double? {
        guard delta != 0 else { return nil }
        originOffset += delta
        lastDelta = delta
        let now = clock.now()
        guard now - lastSentAt >= EventCoalescer.interval else { return nil }
        lastSentAt = now
        return originOffset
    }

    public func flushForEnd() -> Double {
        originOffset
    }
}
