import CoreGraphics
import Foundation
import GrabbyEngines

/// Swallows the action button's down and up and reports them. Left and right are never in the mask.
final class ButtonTap: @unchecked Sendable {
    private let thread: TapThread
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let lock = NSLock()
    private var _actionButton: Int?

    /// Set when a down was let through because another button was held; the matching up passes too.
    private var passingThroughUntilUp = false

    var onDown: (@Sendable (CGPoint) -> Void)?
    var onUp: (@Sendable () -> Void)?

    var actionButton: Int? {
        get { lock.withLock { _actionButton } }
        set { lock.withLock { _actionButton = newValue } }
    }

    init(thread: TapThread) {
        self.thread = thread
    }

    /// Returns false when the tap cannot be created, which means Accessibility access is missing.
    func create() -> Bool {
        thread.sync { [self] in
            if tap != nil { return true }
            let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
            let info = Unmanaged.passUnretained(self).toOpaque()
            guard let port = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                               options: .defaultTap, eventsOfInterest: mask,
                                               callback: buttonTapCallback, userInfo: info) else {
                Log.tap.error("ButtonTap: tapCreate returned nil (no Accessibility access?)")
                return false
            }
            tap = port
            let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            source = src
            CFRunLoopAddSource(thread.runLoop, src, .defaultMode)
            Log.tap.info("ButtonTap: created")
            return true
        }
    }

    func destroy() {
        thread.sync { [self] in
            if let src = source { CFRunLoopRemoveSource(thread.runLoop, src, .defaultMode) }
            if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
            source = nil
            tap = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        thread.async { [self] in
            if let t = tap { CGEvent.tapEnable(tap: t, enable: enabled) }
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            Log.tap.warning("ButtonTap disabled by timeout, re-enabling")
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput {
            Log.tap.warning("ButtonTap disabled by user input")
            return Unmanaged.passUnretained(event)
        }
        if GrabbyEventSource.isOwnEvent(event) { return Unmanaged.passUnretained(event) }
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard let action = actionButton, button == action else { return Unmanaged.passUnretained(event) }
        if type == .otherMouseDown {
            // Never start a gesture on top of a live left or right button drag: injecting a swipe into
            // a drag-and-drop session can leave the dragged item stuck to the cursor.
            if CGEventSource.buttonState(.combinedSessionState, button: .left)
                || CGEventSource.buttonState(.combinedSessionState, button: .right) {
                passingThroughUntilUp = true
                Trace.log("button \(button) down ignored: another button is held")
                return Unmanaged.passUnretained(event)
            }
            passingThroughUntilUp = false
            Log.tap.debug("ButtonTap: action button \(button) down")
            onDown?(event.location)
        } else {
            if passingThroughUntilUp {
                passingThroughUntilUp = false
                return Unmanaged.passUnretained(event)
            }
            Log.tap.debug("ButtonTap: action button \(button) up")
            onUp?()
        }
        return nil
    }
}

private func buttonTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                               userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    return Unmanaged<ButtonTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
}
