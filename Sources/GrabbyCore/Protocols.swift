import Foundation

public enum Axis: Sendable, Equatable {
    case horizontal, vertical
}

public enum StepCommand: Sendable, Equatable {
    case moveSpaceLeft, moveSpaceRight, missionControl, appExpose, showDesktop
}

/// What holding the action button and moving the mouse does.
public enum HoldAction: String, Codable, Sendable {
    /// Pick up the window under the pointer and move it, like three-finger drag on a trackpad.
    case moveWindow
    /// Slide between desktops and open Mission Control, like a three-finger swipe.
    case switchDesktops
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

public protocol WindowMover: AnyObject {
    /// Returns false when there is no movable window under the pointer.
    func grabWindow(at point: Point) -> Bool
    func moveGrabbedWindow(dx: Double, dy: Double)
    func releaseWindow()
}

public protocol UserNotifier: AnyObject {
    func showFallbackNotice()
}
