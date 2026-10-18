# Contract: GrabbyCore public API

`GrabbyCore` is a Swift library target with no AppKit, CoreGraphics or IOKit import.
The app and the tests both program against this surface. Signatures are the contract;
bodies are implementation.

## Side-effect protocols (implemented by the app, faked by tests)

```swift
public protocol Clock: Sendable {
    func now() -> Duration          // monotonic
}

public protocol GestureOutput: AnyObject {
    // Smooth engine
    func dockSwipeBegan(axis: Axis, progress: Double)
    func dockSwipeChanged(progress: Double)                       // already coalesced
    func dockSwipeEnded(progress: Double, exitSpeed: Double)
    func dockSwipeCancelled(progress: Double, exitSpeed: Double)
    // Keyboard engine and catch-up
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
```

## Types

```swift
public enum Axis: Sendable, Equatable { case horizontal, vertical }
public enum StepCommand: Sendable, Equatable {
    case moveSpaceLeft, moveSpaceRight, missionControl, appExpose, showDesktop
}
public enum SwitchingStyle: String, Codable, Sendable { case smooth, keyboard }
public enum DragDownAction: String, Codable, Sendable { case appExpose, showDesktop, none }
public enum TapAction: String, Codable, Sendable {
    case missionControl, appExpose, showDesktop, none, passThrough
}
public struct Point: Sendable, Equatable { public var x, y: Double }
public struct Size: Sendable, Equatable { public var width, height: Double }
```

## Settings

```swift
public struct Settings: Codable, Sendable, Equatable {
    public static let current = 1
    public var schemaVersion: Int
    public var actionButton: Int?
    public var switchingStyle: SwitchingStyle
    public var dragDownAction: DragDownAction
    public var tapAction: TapAction
    public var naturalDirection: Bool?
    public var pinPointer: Bool
    public var launchAtLogin: Bool
    public static let defaults: Settings
    public func validated() throws -> Settings      // throws SettingsError.invalidButton
}

public struct SettingsStore {
    public init(read: @Sendable () throws -> Data?, write: @Sendable (Data) throws -> Void)
    public func load() -> Settings                 // defaults on missing or undecodable
    public func save(_ settings: Settings) throws
}
```

## GestureRecognizer

```swift
public enum GestureEvent: Equatable {
    case tap
    case dragBegan(Axis)
    case dragChanged(Double)          // delta along the locked axis, raw points
    case dragEnded
    case dragCancelled
}

public struct GestureRecognizer {
    public static let threshold: Double = 7
    public init()
    public mutating func buttonDown() -> [GestureEvent]      // always []
    public mutating func move(dx: Double, dy: Double) -> [GestureEvent]
    public mutating func buttonUp() -> [GestureEvent]
    public mutating func cancel() -> [GestureEvent]
    public var isDragging: Bool { get }
    public var axis: Axis? { get }
    public var distance: Double { get }                       // signed, along axis
}
```

## SwipeProgressScaler

```swift
public struct SwipeProgressScaler: Sendable {
    public init(screen: Size, spaceCount: Int, naturalDirection: Bool)
    public static let spaceSeparatorWidth: Double = 63
    public func horizontalProgress(forDelta dx: Double) -> Double
    public func verticalProgress(forDelta dy: Double) -> Double
}
```

Horizontal: `-dx * (offsetForOneSpace / (screen.width + 63))`, then negated again
when `naturalDirection` is true. `offsetForOneSpace` is 2 for one Space and
`1 + 1/(n-1)` otherwise. Vertical: `dy / screen.height`, same sign rule.

## EventCoalescer

```swift
public struct EventCoalescer {
    public static let interval: Duration = .milliseconds(8)
    public init(clock: Clock)
    public mutating func began(progress: Double) -> Double       // resets, returns progress
    public mutating func changed(delta: Double) -> Double?       // nil = held back
    public mutating func flushForEnd() -> Double                 // accumulated origin offset
    public var originOffset: Double { get }
    public var lastDelta: Double { get }
}
```

## EndPhaseDecider

```swift
public enum EndPhase: Equatable { case ended, cancelled }
public enum EndPhaseDecider {
    public static func phase(lastDelta: Double, originOffset: Double) -> EndPhase
    public static func exitSpeed(lastDelta: Double) -> Double     // lastDelta * 100
}
```

## DiscreteStepper

```swift
public struct DiscreteStepper {
    public static let firstStep: Double = 60
    public static let nextStep: Double = 200
    public init(axis: Axis, dragDownAction: DragDownAction)
    public mutating func move(delta: Double) -> [StepCommand]
}
```

## FallbackDecider

```swift
public struct FallbackObservation: Equatable {
    public var axis: Axis
    public var distance: Double
    public var spaceBefore: UInt64
    public var spaceAfter: UInt64
    public var hardError: Bool
    public var consecutiveFailures: Int
}
public struct FallbackVerdict: Equatable {
    public var catchUpStep: StepCommand?
    public var failureCount: Int
    public var becameSticky: Bool
}
public enum FallbackDecider {
    public static let stickyAfter = 2
    public static func decide(_ o: FallbackObservation) -> FallbackVerdict
}
```

## GestureController

The orchestrator the app drives. Everything else is reachable through it.

```swift
public final class GestureController {
    public init(settings: Settings, smoothAvailable: Bool, clock: Clock,
                output: GestureOutput, spaces: SpaceReader,
                pointer: PointerPin, notifier: UserNotifier)
    public var settings: Settings { get set }
    public var stickyFallback: Bool { get }
    public func actionButtonDown(at origin: Point)
    public func pointerMoved(dx: Double, dy: Double)
    public func actionButtonUp()
    public func cancelGesture()
    /// Called by the app 400 ms after a smooth gesture ends, with the Space id read then.
    public func verifySmoothGesture(spaceAfter: UInt64)
    /// For the tap action "passThrough"; the app replays the click when this returns true.
    public var lastTapWasPassThrough: Bool { get }
}
```

Observable behaviour the tests pin down:

- Tap: `output.perform` receives the tap action's step, or nothing for `none`,
  and `lastTapWasPassThrough` is true for `passThrough`.
- Horizontal drag, smooth: `dockSwipeBegan(.horizontal, p)` once, coalesced
  `dockSwipeChanged`, then `dockSwipeEnded` or `dockSwipeCancelled`; `pointer.pin`
  on began and `pointer.unpin` on end when `pinPointer` is true.
- Horizontal drag, keyboard: `perform(.moveSpaceLeft/Right)` per stepper rules; no
  dock swipe calls.
- Vertical up: smooth path or `perform(.missionControl)`. Vertical down:
  configured action; `showDesktop` always via `perform`.
- `verifySmoothGesture` with an unchanged Space after a committed horizontal drag
  calls `perform` with the catch-up step; after two failures `stickyFallback` is
  true, `notifier.showFallbackNotice()` was called exactly once, and the next drag
  uses the keyboard path.
- `cancelGesture` while dragging emits `dockSwipeCancelled` and `pointer.unpin`.
