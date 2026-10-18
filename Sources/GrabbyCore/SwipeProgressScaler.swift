import Foundation

/// Converts pointer deltas into Dock Swipe progress. Measured against real trackpad events on
/// macOS 27: one desktop is progress 1.0 whatever the Space count, and a finger moving left is
/// negative. One screen width plus the Spaces separator of hand travel is one desktop.
public struct SwipeProgressScaler: Sendable {
    public static let spaceSeparatorWidth: Double = 63

    public let offsetForOneSpace: Double = 1.0
    private let horizontalScale: Double
    private let verticalScale: Double
    private let sign: Double

    public init(screen: Size, spaceCount: Int, naturalDirection: Bool) {
        horizontalScale = offsetForOneSpace / (screen.width + SwipeProgressScaler.spaceSeparatorWidth)
        verticalScale = 1.0 / screen.height
        sign = naturalDirection ? -1 : 1
    }

    public func horizontalProgress(forDelta dx: Double) -> Double {
        dx * horizontalScale * sign
    }

    public func verticalProgress(forDelta dy: Double) -> Double {
        dy * verticalScale * sign
    }
}
