import Foundation

/// Converts raw pointer deltas into Dock Swipe progress so one screen width is one Space.
/// Constants come from Mac Mouse Fix's measurements (see research.md R3).
public struct SwipeProgressScaler: Sendable {
    public static let spaceSeparatorWidth: Double = 63

    private let horizontalScale: Double
    private let verticalScale: Double
    private let sign: Double

    public init(screen: Size, spaceCount: Int, naturalDirection: Bool) {
        let offsetForOneSpace = spaceCount <= 1 ? 2.0 : 1.0 + 1.0 / Double(spaceCount - 1)
        horizontalScale = offsetForOneSpace / (screen.width + SwipeProgressScaler.spaceSeparatorWidth)
        verticalScale = 1.0 / screen.height
        sign = naturalDirection ? -1 : 1
    }

    public func horizontalProgress(forDelta dx: Double) -> Double {
        -dx * horizontalScale * sign
    }

    public func verticalProgress(forDelta dy: Double) -> Double {
        dy * verticalScale * sign
    }
}
