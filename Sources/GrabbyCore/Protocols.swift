import Foundation

public enum Axis: Sendable, Equatable {
    case horizontal, vertical
}

public enum StepCommand: Sendable, Equatable {
    case moveSpaceLeft, moveSpaceRight, missionControl, appExpose, showDesktop
}

public enum SwitchingStyle: String, Codable, Sendable {
    case smooth, keyboard
}

public enum DragDownAction: String, Codable, Sendable {
    case appExpose, showDesktop, none
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
    func activeSpace() -> UInt64
    func spaceCount(onDisplayUnderPointer: Bool) -> Int
    func screenSize() -> Size
}

public protocol PointerPin: AnyObject {
    func pin(at origin: Point)
    func unpin()
}

public protocol UserNotifier: AnyObject {
    func showFallbackNotice()
}
