import CoreGraphics
import Foundation

/// Debug only: a listen-only tap that records every Dock Swipe CGEvent (types 29 and 30) in the
/// session, real or synthetic, with its IOHIDEvent fields. Active only while the trace file exists.
/// Lets a genuine trackpad swipe be compared field by field with what Grabby posts.
public final class GestureInspector: @unchecked Sendable {
    private typealias CopyHID = @convention(c) (CGEvent) -> Unmanaged<CFTypeRef>?
    private typealias GetU64 = @convention(c) (CFTypeRef) -> UInt64
    private typealias GetU32 = @convention(c) (CFTypeRef) -> UInt32
    private typealias GetU16 = @convention(c) (CFTypeRef) -> UInt16
    private typealias GetInt = @convention(c) (CFTypeRef, UInt32) -> CFIndex
    private typealias GetFloat = @convention(c) (CFTypeRef, UInt32) -> Double
    private typealias GetChildren = @convention(c) (CFTypeRef) -> Unmanaged<CFArray>?

    private let copyHID: CopyHID?
    private let getType: GetU32?
    private let getFlags: GetU32?
    private let getPhase: GetU16?
    private let getSender: GetU64?
    private let getTimestamp: GetU64?
    private let getInt: GetInt?
    private let getFloat: GetFloat?
    private let getChildren: GetChildren?

    private var tap: CFMachPort?
    private var lines = 0
    private static let maxLines = 2000

    public init() {
        let cg = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY)
        let io = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)
        func sym<T>(_ h: UnsafeMutableRawPointer?, _ n: String, _ t: T.Type) -> T? {
            guard let h, let p = dlsym(h, n) else { return nil }
            return unsafeBitCast(p, to: t)
        }
        copyHID = sym(cg, "CGEventCopyIOHIDEvent", CopyHID.self)
        getType = sym(io, "IOHIDEventGetType", GetU32.self)
        getFlags = sym(io, "IOHIDEventGetEventFlags", GetU32.self)
        getPhase = sym(io, "IOHIDEventGetPhase", GetU16.self)
        getSender = sym(io, "IOHIDEventGetSenderID", GetU64.self)
        getTimestamp = sym(io, "IOHIDEventGetTimeStamp", GetU64.self)
        getInt = sym(io, "IOHIDEventGetIntegerValue", GetInt.self)
        getFloat = sym(io, "IOHIDEventGetFloatValue", GetFloat.self)
        getChildren = sym(io, "IOHIDEventGetChildren", GetChildren.self)
    }

    /// Installs the tap on the current run loop. Returns false without Accessibility or trace.
    @discardableResult
    public func start() -> Bool {
        guard FileManager.default.fileExists(atPath: Trace.url.path) else { return false }
        let mask: CGEventMask = (1 << 29) | (1 << 30)
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                           eventsOfInterest: mask, callback: inspectorCallback, userInfo: info) else {
            Trace.log("inspector: could not create tap")
            return false
        }
        tap = port
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        Trace.log("inspector: recording Dock Swipe events (types 29/30), copyHID=\(copyHID != nil)")
        return true
    }

    fileprivate func inspect(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout, let tap { CGEvent.tapEnable(tap: tap, enable: true); return }
        guard lines < GestureInspector.maxLines else { return }
        lines += 1
        let own = GrabbyEventSource.isOwnEvent(event)
        let ts = event.timestamp
        guard type.rawValue == 30, let copyHID, let hid = copyHID(event)?.takeRetainedValue() else {
            Trace.log("inspect cg type=\(type.rawValue) ts=\(ts) own=\(own) (no HID payload)")
            return
        }
        let t = getType?(hid) ?? 0
        let flags = getFlags?(hid) ?? 0
        let phase = getPhase?(hid) ?? 0
        let sender = getSender?(hid) ?? 0
        let hts = getTimestamp?(hid) ?? 0
        var fields = ""
        if t == 23, let getInt, let getFloat {
            let base: UInt32 = 23 << 16
            fields = String(format: " mask=%ld motion=%ld flavor=%ld progress=%.5f pos=(%.3f, %.3f, %.3f)",
                            getInt(hid, base | 0), getInt(hid, base | 1), getInt(hid, base | 5),
                            getFloat(hid, base | 2), getFloat(hid, base | 3), getFloat(hid, base | 4), getFloat(hid, base | 6))
        }
        var kids = ""
        if let getChildren, let arr = getChildren(hid)?.takeUnretainedValue() as? [CFTypeRef], !arr.isEmpty {
            kids = " children=" + arr.map { child -> String in
                let ct = getType?(child) ?? 0
                if ct == 9, let getFloat {
                    let vb: UInt32 = 9 << 16
                    return String(format: "velocity(%.3f, %.3f, %.3f)", getFloat(child, vb | 0), getFloat(child, vb | 1), getFloat(child, vb | 2))
                }
                return "type\(ct)"
            }.joined(separator: ",")
        }
        Trace.log("inspect hid type=\(t) phase=\(phase) flags=0x\(String(flags, radix: 16)) sender=0x\(String(sender, radix: 16)) hts=\(hts) cgts=\(ts) own=\(own)\(fields)\(kids)")
    }
}

private func inspectorCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                               userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let userInfo {
        Unmanaged<GestureInspector>.fromOpaque(userInfo).takeUnretainedValue().inspect(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
