import CoreGraphics
import Foundation
import GrabbyEngines

/// Catches left and right clicks only while the action button is held, so a click can trigger
/// a screenshot action instead of reaching whatever is under the pointer.
final class ComboTap: @unchecked Sendable {
    private let thread: TapThread
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var swallowUpFor: Set<UInt32> = []

    /// Return true to swallow the click.
    var onClick: (@Sendable (CGMouseButton) -> Bool)?

    init(thread: TapThread) {
        self.thread = thread
    }

    func create() -> Bool {
        thread.sync { [self] in
            if tap != nil { return true }
            let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
                | (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.rightMouseUp.rawValue)
            let info = Unmanaged.passUnretained(self).toOpaque()
            guard let port = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                               options: .defaultTap, eventsOfInterest: mask,
                                               callback: comboTapCallback, userInfo: info) else {
                Log.tap.error("ComboTap: tapCreate returned nil")
                return false
            }
            CGEvent.tapEnable(tap: port, enable: false)
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

    /// Must be called on the tap thread.
    func setEnabled(_ enabled: Bool) {
        if !enabled { swallowUpFor.removeAll() }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: enabled) }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput || GrabbyEventSource.isOwnEvent(event) {
            return Unmanaged.passUnretained(event)
        }
        let button: CGMouseButton = (type == .leftMouseDown || type == .leftMouseUp) ? .left : .right
        switch type {
        case .leftMouseDown, .rightMouseDown:
            if onClick?(button) == true {
                swallowUpFor.insert(button.rawValue)
                Trace.log("combo \(button == .left ? "left" : "right") click swallowed")
                return nil
            }
            return Unmanaged.passUnretained(event)
        case .leftMouseUp, .rightMouseUp:
            if swallowUpFor.remove(button.rawValue) != nil { return nil }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

private func comboTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    return Unmanaged<ComboTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
}
