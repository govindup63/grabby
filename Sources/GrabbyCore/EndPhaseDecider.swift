import Foundation

public enum EndPhase: Equatable, Sendable {
    case ended, cancelled
}

public enum EndPhaseDecider {
    /// With throw on, a final delta against the accumulated offset means the user flicked back.
    /// With throw at zero the desktop only ever follows the mouse, so the release position decides.
    public static func phase(lastDelta: Double, originOffset: Double, throwStrength: Double) -> EndPhase {
        if throwStrength <= 0 || lastDelta == 0 || originOffset == 0 { return .ended }
        return (lastDelta < 0) == (originOffset < 0) ? .ended : .cancelled
    }

    public static func exitSpeed(lastDelta: Double, throwStrength: Double) -> Double {
        lastDelta * 100 * throwStrength
    }
}

/// Adds a little carry to the release position so a flick can finish the move. Capped so a
/// throw never jumps more than most of one desktop.
public enum ThrowResolver {
    public static let gain: Double = 25
    public static let maxCarryOfOneSpace: Double = 0.6

    public static func finalProgress(originOffset: Double, lastDelta: Double, throwStrength: Double, oneSpace: Double) -> Double {
        guard throwStrength > 0 else { return originOffset }
        let cap = maxCarryOfOneSpace * oneSpace
        let carry = min(cap, max(-cap, lastDelta * gain * oneSpace)) * throwStrength
        return originOffset + carry
    }
}
