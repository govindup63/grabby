import Foundation

/// Collapses "changed" progress updates to one per display frame without losing motion. A real
/// trackpad sends one update per refresh of the display it drives; sending faster only makes the
/// window server re-lay out the Spaces strip between frames.
public struct EventCoalescer {
    public static let interval: Duration = .milliseconds(8)
    public let interval: Duration

    public static let velocityWindow: Duration = .milliseconds(80)

    private let clock: any GrabbyClock
    private var lastSentAt: Duration = .zero
    private var samples: [(time: Duration, offset: Double)] = []
    public private(set) var originOffset: Double = 0
    public private(set) var lastDelta: Double = 0

    public init(clock: any GrabbyClock, interval: Duration = EventCoalescer.interval) {
        self.clock = clock
        self.interval = interval
    }

    public mutating func began(progress: Double) -> Double {
        originOffset = progress
        lastDelta = progress
        lastSentAt = clock.now()
        samples = [(lastSentAt, progress)]
        return progress
    }

    /// Returns the accumulated origin offset when it is time to send, nil when held back.
    public mutating func changed(delta: Double) -> Double? {
        guard delta != 0 else { return nil }
        originOffset += delta
        lastDelta = delta
        let now = clock.now()
        samples.append((now, originOffset))
        samples.removeAll { now - $0.time > EventCoalescer.velocityWindow }
        guard now - lastSentAt >= interval else { return nil }
        lastSentAt = now
        return originOffset
    }

    public func flushForEnd() -> Double {
        originOffset
    }

    /// Instantaneous progress per second: the latest sample against the newest sample at least
    /// 8 ms older, within the last 80 ms. Zero when the hand has been still longer than that.
    public func velocity(now: Duration) -> Double {
        let recent = samples.filter { now - $0.time <= EventCoalescer.velocityWindow }
        guard let last = recent.last else { return 0 }
        let anchor = recent.last(where: { last.time - $0.time >= EventCoalescer.interval }) ?? recent.first!
        guard last.time > anchor.time else { return 0 }
        let span = last.time - anchor.time
        let seconds = Double(span.components.seconds) + Double(span.components.attoseconds) / 1e18
        return (last.offset - anchor.offset) / seconds
    }
}
