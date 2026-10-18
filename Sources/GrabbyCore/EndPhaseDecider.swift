import Foundation

public enum EndPhase: Equatable, Sendable {
    case ended, cancelled
}

/// Release mimics the trackpad driver: always "ended", carrying the release velocity, and the Dock
/// decides to commit or slide back from progress and velocity. Throw scales the velocity we report.
public enum ReleaseDecider {
    /// The Dock needs a direction even when the hand is still; a nudge this small never flings.
    public static let minimumNudge: Double = 0.05
    public static let commitFraction: Double = 0.5

    public static func exitSpeed(velocity: Double, progress: Double, throwStrength: Double) -> Double {
        let scaled = velocity * throwStrength
        if abs(scaled) >= minimumNudge { return scaled }
        if progress == 0 { return 0 }
        return progress < 0 ? -minimumNudge : minimumNudge
    }

    /// Whether the Dock is expected to complete the switch given only the release position.
    public static func looksCommitted(progress: Double) -> Bool {
        abs(progress) >= commitFraction
    }
}
