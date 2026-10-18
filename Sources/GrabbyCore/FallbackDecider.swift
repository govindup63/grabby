import Foundation

public struct FallbackObservation: Equatable, Sendable {
    public var axis: Axis
    public var distance: Double
    public var spaceBefore: UInt64
    public var spaceAfter: UInt64
    public var hardError: Bool
    public var consecutiveFailures: Int
    public var naturalDirection: Bool
    public var dragDownAction: DragDownAction

    public init(axis: Axis, distance: Double, spaceBefore: UInt64, spaceAfter: UInt64, hardError: Bool,
                consecutiveFailures: Int, naturalDirection: Bool, dragDownAction: DragDownAction) {
        self.axis = axis
        self.distance = distance
        self.spaceBefore = spaceBefore
        self.spaceAfter = spaceAfter
        self.hardError = hardError
        self.consecutiveFailures = consecutiveFailures
        self.naturalDirection = naturalDirection
        self.dragDownAction = dragDownAction
    }
}

public struct FallbackVerdict: Equatable, Sendable {
    public var catchUpStep: StepCommand?
    public var failureCount: Int
    public var becameSticky: Bool
}

/// Decides, after a smooth gesture, whether it silently failed and what the keyboard path must do about it.
public enum FallbackDecider {
    public static let stickyAfter = 2

    public static func decide(_ o: FallbackObservation) -> FallbackVerdict {
        let committed = abs(o.distance) >= DiscreteStepper.firstStep
        if !committed && !o.hardError {
            // Too short to tell anything; neither a success nor a failure.
            return FallbackVerdict(catchUpStep: nil, failureCount: o.consecutiveFailures, becameSticky: false)
        }
        let silentMiss = o.axis == .horizontal && committed && o.spaceBefore == o.spaceAfter
        let failed = o.hardError || silentMiss
        guard failed else {
            return FallbackVerdict(catchUpStep: nil, failureCount: 0, becameSticky: false)
        }
        let count = o.consecutiveFailures + 1
        return FallbackVerdict(catchUpStep: committed ? catchUp(for: o) : nil,
                               failureCount: count,
                               becameSticky: count >= stickyAfter)
    }

    private static func catchUp(for o: FallbackObservation) -> StepCommand? {
        switch o.axis {
        case .horizontal:
            return DiscreteStepper.horizontalStep(forDistance: o.distance, naturalDirection: o.naturalDirection)
        case .vertical:
            if o.distance < 0 { return .missionControl }
            switch o.dragDownAction {
            case .appExpose: return .appExpose
            case .showDesktop: return .showDesktop
            case .none: return nil
            }
        }
    }
}
