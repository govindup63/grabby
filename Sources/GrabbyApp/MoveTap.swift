import CoreGraphics
import Foundation
import GrabbyCore
import GrabbyEngines

/// Reports raw pointer deltas while enabled. Enabled only between action-button down and up.
/// Also implements pointer pinning by warping the cursor back to the drag origin.
final class MoveTap: PointerPin, @unchecked Sendable {
    private let thread: TapThread
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let lock = NSLock()
    private var _pinOrigin: CGPoint?

    var onMove: (@Sendable (Double, Double) -> Void)?

    var pinOrigin: CGPoint? {
        get { lock.withLock { _pinOrigin } }
        set { lock.withLock { _pinOrigin = newValue } }
    }

    init(thread: TapThread) {
        self.thread = thread
    }

    func create() -> Bool {
        thread.sync { [self] in
            if tap != nil { return true }
            let mask: CGEventMask = (1 << CGEventType.otherMouseDragged.rawValue) | (1 << CGEventType.mouseMoved.rawValue)
            let info = Unmanaged.passUnretained(self).toOpaque()
            guard let port = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                               options: .defaultTap, eventsOfInterest: mask,
                                               callback: moveTapCallback, userInfo: info) else {
                Log.tap.error("MoveTap: tapCreate returned nil")
                return false
            }
            CGEvent.tapEnable(tap: port, enable: false)
            tap = port
            let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            source = src
            CFRunLoopAddSource(thread.runLoop, src, .defaultMode)
            Log.tap.info("MoveTap: created (disabled)")
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

    /// Must be called on the tap thread.
    func setEnabled(_ enabled: Bool) {
        lastLocation = nil
        if let t = tap { CGEvent.tapEnable(tap: t, enable: enabled) }
    }

    private var lastLocation: CGPoint?

    var isEnabled: Bool {
        thread.sync { [self] in tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    }

    // MARK: PointerPin

    func pin(at origin: Point) {
        pinOrigin = CGPoint(x: origin.x, y: origin.y)
    }

    func unpin() {
        pinOrigin = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            Log.tap.warning("MoveTap disabled by timeout, re-enabling")
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput { return Unmanaged.passUnretained(event) }
        if GrabbyEventSource.isOwnEvent(event) { return Unmanaged.passUnretained(event) }
        // Pointer travel on screen (accelerated points) when the pointer is free, so the desktop moves
        // as far as the hand does. Raw device counts when pinned, because the pointer does not move.
        let dx: Double
        let dy: Double
        if let origin = pinOrigin {
            dx = Double(event.getIntegerValueField(.mouseEventDeltaX))
            dy = Double(event.getIntegerValueField(.mouseEventDeltaY))
            CGWarpMouseCursorPosition(origin)
        } else {
            let location = event.location
            let last = lastLocation ?? location
            dx = location.x - last.x
            dy = location.y - last.y
            lastLocation = location
        }
        onMove?(dx, dy)
        return Unmanaged.passUnretained(event)
    }
}

private func moveTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                             userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    return Unmanaged<MoveTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
}
