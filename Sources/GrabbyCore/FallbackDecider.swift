import Foundation

public struct FallbackObservation: Equatable, Sendable {
    public var axis: Axis
    /// Dock progress at release; 1.0 is one desktop.
    public var progress: Double
    public var spaceBefore: UInt64
    public var spaceAfter: UInt64
    public var hardError: Bool
    public var consecutiveFailures: Int
    public var naturalDirection: Bool

    public init(axis: Axis, progress: Double, spaceBefore: UInt64, spaceAfter: UInt64, hardError: Bool,
                consecutiveFailures: Int, naturalDirection: Bool) {
        self.axis = axis
        self.progress = progress
        self.spaceBefore = spaceBefore
        self.spaceAfter = spaceAfter
        self.hardError = hardError
        self.consecutiveFailures = consecutiveFailures
        self.naturalDirection = naturalDirection
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
        // Only hard errors count. An unchanged Space after a committed-looking drag is normal:
        // the Dock weighs release velocity too and may have slid back. Verified against real
        // trackpad recordings on macOS 27.
        guard o.hardError else {
            return FallbackVerdict(catchUpStep: nil, failureCount: 0, becameSticky: false)
        }
        let count = o.consecutiveFailures + 1
        let committed = ReleaseDecider.looksCommitted(progress: o.progress)
        return FallbackVerdict(catchUpStep: committed ? catchUp(for: o) : nil,
                               failureCount: count,
                               becameSticky: count >= stickyAfter)
    }

    private static func catchUp(for o: FallbackObservation) -> StepCommand? {
        switch o.axis {
        case .horizontal:
            return DiscreteStepper.horizontalStep(forDistance: o.progress, naturalDirection: o.naturalDirection)
        case .vertical:
            return .missionControl
        }
    }
}
