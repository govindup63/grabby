import Foundation

public enum EndPhase: Equatable, Sendable {
    case ended, cancelled
}

public enum EndPhaseDecider {
    public static let commitFraction: Double = 0.5

    /// The Dock treats "ended" as commit to the next desktop and "cancelled" as snap back, whatever
    /// the progress value. So: commit when the release point (plus any throw carry) is at least half
    /// a desktop along. With throw on, a flick against the direction of travel snaps back instead.
    public static func phase(lastDelta: Double, originOffset: Double, throwStrength: Double, oneSpace: Double) -> EndPhase {
        if throwStrength > 0, lastDelta != 0, originOffset != 0, (lastDelta < 0) != (originOffset < 0) {
            return .cancelled
        }
        let final = ThrowResolver.finalProgress(originOffset: originOffset, lastDelta: lastDelta,
                                                throwStrength: throwStrength, oneSpace: oneSpace)
        return abs(final) >= commitFraction * oneSpace ? .ended : .cancelled
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
