import Foundation

public enum Axis: Sendable, Equatable {
    case horizontal, vertical
}

public enum StepCommand: Sendable, Equatable {
    case moveSpaceLeft, moveSpaceRight, missionControl, appExpose, showDesktop
    /// The system's area screenshot (what Command Shift 4 is bound to).
    case screenshotSelection
    /// The system's screenshot and recording panel (what Command Shift 5 is bound to).
    case screenshotOptions
}

/// A left or right click made while the action button is held.
public enum ComboButton: Sendable, Equatable {
    case left, right
}

public enum TapAction: String, Codable, Sendable {
    case missionControl, appExpose, showDesktop, none, passThrough
}

public struct Point: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Size: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Monotonic time source. Named to avoid clashing with Swift's `Clock` protocol.
public protocol GrabbyClock: Sendable {
    func now() -> Duration
}

public protocol GestureOutput: AnyObject {
    func dockSwipeBegan(axis: Axis, progress: Double)
    func dockSwipeChanged(progress: Double)
    func dockSwipeEnded(progress: Double, exitSpeed: Double)
    func dockSwipeCancelled(progress: Double, exitSpeed: Double)
    func perform(_ step: StepCommand)
}

public protocol SpaceReader: AnyObject {
    func missionControlIsActive() -> Bool
    func activeSpace() -> UInt64
    func spaceCount(onDisplayUnderPointer: Bool) -> Int
    func screenSize() -> Size
}

public protocol UserNotifier: AnyObject {
    func showFallbackNotice()
}
