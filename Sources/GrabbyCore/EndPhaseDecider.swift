import Foundation

public enum EndPhase: Equatable, Sendable {
    case ended, cancelled
}

public enum EndPhaseDecider {
    /// A final delta pointing against the accumulated offset means the user changed their mind.
    public static func phase(lastDelta: Double, originOffset: Double) -> EndPhase {
        if lastDelta == 0 || originOffset == 0 { return .ended }
        return (lastDelta < 0) == (originOffset < 0) ? .ended : .cancelled
    }

    public static func exitSpeed(lastDelta: Double) -> Double {
        lastDelta * 100
    }
}
