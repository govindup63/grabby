import Foundation

public enum GestureEvent: Equatable, Sendable {
    case tap
    case dragBegan(Axis)
    case dragChanged(Double)
    case dragEnded
    case dragCancelled
}

/// Turns button down/up and raw deltas into tap and drag events. Pure; no timing.
public struct GestureRecognizer: Sendable {
    public static let threshold: Double = 7

    private enum State: Equatable {
        case idle
        case pressed
        case dragging(Axis)
    }

    private var state: State = .idle
    private var offsetX: Double = 0
    private var offsetY: Double = 0

    public init() {}

    public var isDragging: Bool {
        if case .dragging = state { return true }
        return false
    }

    public var axis: Axis? {
        if case .dragging(let a) = state { return a }
        return nil
    }

    /// Signed sum of deltas along the locked axis (horizontal until locked).
    public var distance: Double {
        switch state {
        case .dragging(.vertical): return offsetY
        default: return offsetX
        }
    }

    public mutating func buttonDown() -> [GestureEvent] {
        state = .pressed
        offsetX = 0
        offsetY = 0
        return []
    }

    public mutating func move(dx: Double, dy: Double) -> [GestureEvent] {
        switch state {
        case .idle:
            return []
        case .pressed:
            offsetX += dx
            offsetY += dy
            guard max(abs(offsetX), abs(offsetY)) > GestureRecognizer.threshold else { return [] }
            let axis: Axis = abs(offsetY) > abs(offsetX) ? .vertical : .horizontal
            state = .dragging(axis)
            return [.dragBegan(axis)]
        case .dragging(let axis):
            switch axis {
            case .horizontal:
                offsetX += dx
                return [.dragChanged(dx)]
            case .vertical:
                offsetY += dy
                return [.dragChanged(dy)]
            }
        }
    }

    public mutating func buttonUp() -> [GestureEvent] {
        defer { state = .idle }
        switch state {
        case .idle: return []
        case .pressed: return [.tap]
        case .dragging: return [.dragEnded]
        }
    }

    public mutating func cancel() -> [GestureEvent] {
        defer { state = .idle }
        if case .dragging = state { return [.dragCancelled] }
        return []
    }
}
