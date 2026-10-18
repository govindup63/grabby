import Foundation
import GrabbyCore

/// Routes controller output to the two engines and reports smooth-path hard failures.
public final class EngineOutput: GestureOutput, @unchecked Sendable {
    private let dock: DockSwipeEngine
    private let hotkeys: HotkeyEngine
    private let onHardError: @Sendable () -> Void

    public init(dock: DockSwipeEngine, hotkeys: HotkeyEngine, onHardError: @escaping @Sendable () -> Void) {
        self.dock = dock
        self.hotkeys = hotkeys
        self.onHardError = onHardError
    }

    public func dockSwipeBegan(axis: Axis, progress: Double) {
        lastAxis = axis
        if !dock.post(axis: axis, phase: .began, progress: progress) { onHardError() }
    }

    public func dockSwipeChanged(progress: Double) {
        if !dock.post(axis: lastAxis, phase: .changed, progress: progress) { onHardError() }
    }

    public func dockSwipeEnded(progress: Double, exitSpeed: Double) {
        if !dock.post(axis: lastAxis, phase: .ended, progress: progress, exitSpeed: exitSpeed) { onHardError() }
    }

    public func dockSwipeCancelled(progress: Double, exitSpeed: Double) {
        if !dock.post(axis: lastAxis, phase: .cancelled, progress: progress, exitSpeed: exitSpeed) { onHardError() }
    }

    public func perform(_ step: StepCommand) {
        hotkeys.perform(step)
    }

    private var lastAxis: Axis = .horizontal
}
