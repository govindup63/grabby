import Foundation

/// The points behind the pointer during a hold, ready to be drawn as a fading line.
public struct CursorTrail: Sendable {
    /// How long a point stays visible.
    public static let lifetime: Duration = .milliseconds(500)
    public static let maxPoints = 64
    /// Points closer than this to the previous one are dropped, so a still hand adds nothing.
    public static let minimumSpacing: Double = 2

    public struct Segment: Equatable, Sendable {
        public var from: Point
        public var to: Point
        /// 1 for the newest segment, falling to 0 at the end of the lifetime.
        public var alpha: Double
    }

    private var points: [(point: Point, time: Duration)] = []

    public init() {}

    public var isEmpty: Bool { points.isEmpty }

    public mutating func append(_ point: Point, at time: Duration) {
        if let last = points.last {
            let dx = point.x - last.point.x, dy = point.y - last.point.y
            if (dx * dx + dy * dy).squareRoot() < CursorTrail.minimumSpacing { return }
        }
        points.append((point, time))
        if points.count > CursorTrail.maxPoints {
            points.removeFirst(points.count - CursorTrail.maxPoints)
        }
    }

    /// Drops expired points and returns the drawable segments, oldest first.
    public mutating func segments(now: Duration) -> [Segment] {
        points.removeAll { now - $0.time > CursorTrail.lifetime }
        guard points.count >= 2 else { return [] }
        let life = Double(CursorTrail.lifetime.components.seconds) + Double(CursorTrail.lifetime.components.attoseconds) / 1e18
        return zip(points, points.dropFirst()).map { a, b in
            let age = now - b.time
            let seconds = Double(age.components.seconds) + Double(age.components.attoseconds) / 1e18
            return Segment(from: a.point, to: b.point, alpha: max(0, min(1, 1 - seconds / life)))
        }
    }

    public mutating func clear() {
        points.removeAll()
    }
}
