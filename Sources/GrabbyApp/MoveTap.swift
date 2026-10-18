import CoreGraphics
import Foundation
import GrabbyEngines

/// Reports pointer travel on screen while enabled. Enabled only between action-button down and up.
final class MoveTap: @unchecked Sendable {
    private let thread: TapThread
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var lastLocation: CGPoint?

    var onMove: (@Sendable (Double, Double) -> Void)?

    init(thread: TapThread) {
        self.thread = thread
    }

    func create() -> Bool {
        thread.sync { [self] in
            if tap != nil { return true }
            let mask: CGEventMask = (1 << CGEventType.otherMouseDragged.rawValue) | (1 << CGEventType.mouseMoved.rawValue)
            let info = Unmanaged.passUnretained(self).toOpaque()
            // Listen-only: moves are never changed, so never hold the event stream waiting on us.
            guard let port = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                               options: .listenOnly, eventsOfInterest: mask,
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

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            Log.tap.warning("MoveTap disabled by timeout, re-enabling")
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput { return Unmanaged.passUnretained(event) }
        if GrabbyEventSource.isOwnEvent(event) { return Unmanaged.passUnretained(event) }
        // Pointer travel on screen in points, so the desktop moves as far as the hand does.
        let location = event.location
        let last = lastLocation ?? location
        lastLocation = location
        onMove?(location.x - last.x, location.y - last.y)
        return Unmanaged.passUnretained(event)
    }
}

private func moveTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                             userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    return Unmanaged<MoveTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
}
