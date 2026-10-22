import CoreGraphics
import Foundation
import GrabbyCore
import GrabbyEngines

/// Sits between the event taps and the gesture controller.
///
/// The tap callbacks must return immediately: while a filtering tap's callback runs, the window
/// server holds the whole mouse event stream, and anything in there that talks back to the window
/// server deadlocks until the tap times out (seen as 8 second callback latencies and lost drops).
/// So the tap side only flips taps, records the pointer and enqueues; the controller and every
/// window-server round trip run on `queue`, the only queue that touches the controller.
final class GestureBridge: MoveTapTarget, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.pixelstwo.grabby.gesture", qos: .userInteractive)
    private let gate = ComboGate()
    private let controller: GestureController
    private let spaces: SpaceObserver
    private let moveTap: MoveTap
    private let comboTap: ComboTap

    init(controller: GestureController, spaces: SpaceObserver, moveTap: MoveTap, comboTap: ComboTap) {
        self.controller = controller
        self.spaces = spaces
        self.moveTap = moveTap
        self.comboTap = comboTap
    }

    // MARK: Called from the tap thread

    func buttonDown(at location: CGPoint) {
        spaces.notePointer(location)
        gate.open()
        let point = Point(x: location.x, y: location.y)
        queue.async { [self] in
            // CGEventTapEnable is a window-server round trip; keep it out of the tap callback.
            moveTap.setEnabled(true)
            comboTap.setEnabled(true)
            controller.actionButtonDown(at: point)
        }
    }

    func moved(dx: Double, dy: Double, location: CGPoint) {
        spaces.notePointer(location)
        queue.async { [controller] in controller.pointerMoved(dx: dx, dy: dy) }
    }

    /// Returns true when the click is consumed as a hold-plus-click combo.
    func click(_ button: CGMouseButton) -> Bool {
        guard gate.tryConsume() else { return false }
        let combo: ComboButton = button == .left ? .left : .right
        queue.async { [controller] in controller.comboClick(combo) }
        return true
    }

    func buttonUp() {
        gate.close()
        queue.async { [self] in
            moveTap.setEnabled(false)
            comboTap.setEnabled(false)
            controller.actionButtonUp()
            if controller.lastTapWasPassThrough, let button = controller.settings.actionButton {
                replayClick(button: button)
            }
            if controller.awaitingVerification {
                queue.asyncAfter(deadline: .now() + 0.4) { [self] in
                    controller.verifySmoothGesture(spaceAfter: spaces.activeSpace())
                    Log.gesture.debug("Verified smooth gesture, sticky=\(self.controller.stickyFallback)")
                }
            }
        }
    }

    // MARK: Called from the main thread

    func cancel(sync: Bool) {
        gate.close()
        let work = { [self] in
            moveTap.setEnabled(false)
            comboTap.setEnabled(false)
            controller.cancelGesture()
        }
        if sync { queue.sync(execute: work) } else { queue.async(execute: work) }
    }

    func apply(_ settings: Settings) {
        queue.async { [controller] in controller.settings = settings }
    }

    /// Posts the swallowed click again, tagged so ButtonTap lets it through.
    private func replayClick(button: Int) {
        guard let location = spaces.lastKnownPointer else { return }
        let mouseButton = CGMouseButton(rawValue: UInt32(button)) ?? .center
        let source = GrabbyEventSource.shared
        guard let down = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: location, mouseButton: mouseButton),
              let up = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: location, mouseButton: mouseButton) else { return }
        down.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        up.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        Log.tap.debug("Replayed click for button \(button)")
    }
}
