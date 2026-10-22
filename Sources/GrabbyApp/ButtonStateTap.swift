import CoreGraphics
import Foundation
import GrabbyEngines

/// Tracks whether the left or right mouse button is down, from a listen-only tap on just the
/// four button events. Listen-only taps never hold the event stream, unlike asking the system
/// for button state from inside a filtering tap's callback, which deadlocks until the tap times out.
final class ButtonStateTap: @unchecked Sendable {
    private let thread: TapThread
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let lock = NSLock()
    private var leftDown = false
    private var rightDown = false

    init(thread: TapThread) {
        self.thread = thread
    }

    var anyPrimaryButtonDown: Bool {
        lock.withLock { leftDown || rightDown }
    }

    func create() -> Bool {
        thread.sync { [self] in
            if tap != nil { return true }
            let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
                | (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.rightMouseUp.rawValue)
            let info = Unmanaged.passUnretained(self).toOpaque()
            guard let port = CGEvent.tapCreate(tap: .cghidEventTap, place: .tailAppendEventTap,
                                               options: .listenOnly, eventsOfInterest: mask,
                                               callback: buttonStateCallback, userInfo: info) else {
                Log.tap.error("ButtonStateTap: tapCreate returned nil")
                return false
            }
            tap = port
            let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            source = src
            CFRunLoopAddSource(thread.runLoop, src, .defaultMode)
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

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout, let t = tap {
            CGEvent.tapEnable(tap: t, enable: true)
            return
        }
        lock.withLock {
            switch type {
            case .leftMouseDown: leftDown = true
            case .leftMouseUp: leftDown = false
            case .rightMouseDown: rightDown = true
            case .rightMouseUp: rightDown = false
            default: break
            }
        }
    }
}

private func buttonStateCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                 userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let userInfo {
        Unmanaged<ButtonStateTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
