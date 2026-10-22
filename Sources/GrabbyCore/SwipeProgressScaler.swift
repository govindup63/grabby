import Foundation

/// Converts pointer deltas into Dock Swipe progress.
///
/// `.hidEvent` (macOS 27+), measured against real trackpad events: one desktop is progress 1.0
/// whatever the Space count; a finger moving left is negative and a finger moving up is positive.
/// `.legacyFields` (macOS 26 and earlier), Mac Mouse Fix's measured scale for the old event format:
/// one desktop is 1 + 1/(spaces - 1) (2.0 with one Space), leftward motion positive, upward negative.
/// In both, one screen width plus the Spaces separator of hand travel is one desktop.
public struct SwipeProgressScaler: Sendable {
    public static let spaceSeparatorWidth: Double = 63

    public let offsetForOneSpace: Double
    private let horizontalScale: Double
    private let verticalScale: Double
    private let sign: Double

    public init(screen: Size, spaceCount: Int, naturalDirection: Bool, format: DockSwipeFormat = .hidEvent) {
        switch format {
        case .hidEvent:
            offsetForOneSpace = 1.0
            sign = naturalDirection ? -1 : 1
        case .legacyFields:
            offsetForOneSpace = spaceCount <= 1 ? 2.0 : 1.0 + 1.0 / Double(spaceCount - 1)
            sign = naturalDirection ? 1 : -1
        }
        horizontalScale = offsetForOneSpace / (screen.width + SwipeProgressScaler.spaceSeparatorWidth)
        verticalScale = 1.0 / screen.height
    }

    public func horizontalProgress(forDelta dx: Double) -> Double {
        dx * horizontalScale * sign
    }

    public func verticalProgress(forDelta dy: Double) -> Double {
        -dy * verticalScale * sign
    }
}
