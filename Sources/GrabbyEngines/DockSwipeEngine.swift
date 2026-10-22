import CoreGraphics
import Foundation
import GrabbyCore
import GrabbyPrivate

/// Posts synthetic trackpad Dock Swipe gestures the way macOS 27 expects them: an IOHIDEvent
/// attached to a type 30 CGEvent through SkyLight. See research.md R2 and R3.
public final class DockSwipeEngine: @unchecked Sendable {
    public enum Phase {
        case began, changed, ended, cancelled

        var bits: UInt32 {
            switch self {
            case .began: return UInt32(GRABBY_PHASE_BEGAN)
            case .changed: return UInt32(GRABBY_PHASE_CHANGED)
            case .ended: return UInt32(GRABBY_PHASE_ENDED)
            case .cancelled: return UInt32(GRABBY_PHASE_CANCELLED)
            }
        }
    }

    public static let resendDelays: [TimeInterval] = [0.2, 0.5]
    /// Mac Mouse Fix resends end events to clear a rare stuck transition. A stray end event may
    /// itself read as a new discrete swipe, so this is off until proven necessary.
    public var resendEndEvents = false


    public let format: DockSwipeFormat
    /// Reported to the Dock on the legacy path (field 136, "inverted from device").
    public var naturalDirection = true

    private let api: grabby_private_api
    private let fakeFailure: Bool
    private let queue = DispatchQueue(label: "com.pixelstwo.grabby.dockswipe")
    private var resends: [DispatchWorkItem] = []
    private var maskSent = false
    private static let maskThreshold = 0.02

    public init(api: grabby_private_api,
                format: DockSwipeFormat = DockSwipeEngine.formatForThisSystem(),
                fakeFailure: Bool = ProcessInfo.processInfo.environment["GRABBY_FAKE_SMOOTH_FAILURE"] == "1") {
        self.api = api
        self.format = format
        self.fakeFailure = fakeFailure
    }

    public static func formatForThisSystem() -> DockSwipeFormat {
        let v = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(v) ? .hidEvent : .legacyFields
    }

    /// The legacy path needs no private symbols at all; the HID path needs five.
    public var available: Bool {
        switch format {
        case .legacyFields:
            return true
        case .hidEvent:
            return api.IOHIDEventCreate != nil && api.IOHIDEventSetIntegerValue != nil && api.IOHIDEventSetFloatValue != nil
                && api.IOHIDEventAppendEvent != nil && api.SLEventSetIOHIDEvent != nil
        }
    }

    /// Returns false on a hard failure (missing symbol or event creation failure).
    @discardableResult
    public func post(axis: Axis, phase: Phase, progress: Double, exitSpeed: Double = 0) -> Bool {
        if phase == .began { cancelResends(); maskSent = false }
        if fakeFailure {
            Log.engine.debug("DockSwipeEngine: GRABBY_FAKE_SMOOTH_FAILURE set, posting nothing")
            return true
        }
        guard available else { return false }
        let events = makeEvents(axis: axis, phase: phase, progress: progress, exitSpeed: exitSpeed)
        guard !events.isEmpty else { return false }
        events.forEach { $0.post(tap: .cgSessionEventTap) }
        Trace.log("dockswipe \(axis == .horizontal ? "h" : "v") phase=\(phase.bits) progress=\(String(format: "%.4f", progress)) exitSpeed=\(String(format: "%.3f", exitSpeed))")
        Log.engine.debug("DockSwipeEngine: \(axis == .horizontal ? "h" : "v") phase=\(phase.bits) progress=\(progress, format: .fixed(precision: 4))")

        if resendEndEvents, phase == .ended || phase == .cancelled {
            // The end event is occasionally dropped under load; resend it so the transition never sticks.
            for delay in DockSwipeEngine.resendDelays {
                let item = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.makeEvents(axis: axis, phase: phase, progress: progress, exitSpeed: exitSpeed)
                        .forEach { $0.post(tap: .cgSessionEventTap) }
                    Trace.log("dockswipe resend phase=\(phase.bits)")
                }
                resends.append(item)
                queue.asyncAfter(deadline: .now() + delay, execute: item)
            }
        }
        return true
    }

    private func cancelResends() {
        resends.forEach { $0.cancel() }
        resends.removeAll()
    }

    private func makeEvents(axis: Axis, phase: Phase, progress: Double, exitSpeed: Double) -> [CGEvent] {
        switch format {
        case .hidEvent:
            return makeHIDEvent(axis: axis, phase: phase, progress: progress, exitSpeed: exitSpeed).map { [$0] } ?? []
        case .legacyFields:
            return makeLegacyEvents(axis: axis, phase: phase, progress: progress, exitSpeed: exitSpeed)
        }
    }

    /// macOS 26 and earlier. Field numbers and the odd encodings are Mac Mouse Fix's shipped recipe
    /// (TouchSimulator.m, pre-27 branch); the type-30 event carries the gesture, the type-29 event is
    /// the gesture envelope. Unverified on real hardware by this project.
    private func makeLegacyEvents(axis: Axis, phase: Phase, progress: Double, exitSpeed: Double) -> [CGEvent] {
        guard let e30 = CGEvent(source: nil), let e29 = CGEvent(source: nil) else { return [] }
        let valFor41: Double = 33231
        let motion: Double = axis == .horizontal ? 1 : 2
        // A float holding the integer 1 or 2 in its bit pattern, as the Dock expects.
        let motionAsDenormal: Double = axis == .horizontal ? 1.401298464324817e-45 : 2.802596928649634e-45
        let phaseValue = Double(phase.bits)

        e29.setDoubleValueField(CGEventField(rawValue: 55)!, value: 29)
        e29.setDoubleValueField(CGEventField(rawValue: 41)!, value: valFor41)

        e30.setDoubleValueField(CGEventField(rawValue: 55)!, value: 30)
        e30.setDoubleValueField(CGEventField(rawValue: 110)!, value: Double(GRABBY_HID_TYPE_DOCK_SWIPE))
        e30.setDoubleValueField(CGEventField(rawValue: 132)!, value: phaseValue)
        e30.setDoubleValueField(CGEventField(rawValue: 134)!, value: phaseValue)
        e30.setDoubleValueField(CGEventField(rawValue: 124)!, value: progress)
        e30.setIntegerValueField(CGEventField(rawValue: 135)!, value: Int64(Float(progress).bitPattern))
        e30.setDoubleValueField(CGEventField(rawValue: 41)!, value: valFor41)
        e30.setDoubleValueField(CGEventField(rawValue: 119)!, value: motionAsDenormal)
        e30.setDoubleValueField(CGEventField(rawValue: 139)!, value: motionAsDenormal)
        e30.setDoubleValueField(CGEventField(rawValue: 123)!, value: motion)
        e30.setDoubleValueField(CGEventField(rawValue: 165)!, value: motion)
        e30.setIntegerValueField(CGEventField(rawValue: 136)!, value: naturalDirection ? 1 : 0)
        if phase == .ended || phase == .cancelled {
            e30.setDoubleValueField(CGEventField(rawValue: 129)!, value: exitSpeed)
            e30.setDoubleValueField(CGEventField(rawValue: 130)!, value: exitSpeed)
        }
        return [e30, e29]
    }

    private func makeHIDEvent(axis: Axis, phase: Phase, progress: Double, exitSpeed: Double) -> CGEvent? {
        guard let create = api.IOHIDEventCreate, let setInt = api.IOHIDEventSetIntegerValue,
              let setFloat = api.IOHIDEventSetFloatValue, let append = api.IOHIDEventAppendEvent,
              let attach = api.SLEventSetIOHIDEvent else { return nil }

        let options = phase.bits << UInt32(GRABBY_PHASE_SHIFT)
        guard let hid = create(kCFAllocatorDefault, UInt32(GRABBY_HID_TYPE_DOCK_SWIPE), mach_absolute_time(), options) else { return nil }
        let hidEvent = hid.takeRetainedValue()
        let motion = axis == .horizontal ? GRABBY_DOCK_SWIPE_HORIZONTAL : GRABBY_DOCK_SWIPE_VERTICAL
        setInt(hidEvent, UInt32(GRABBY_HID_FIELD_DOCK_SWIPE_MOTION), CFIndex(motion))
        setInt(hidEvent, UInt32(GRABBY_HID_FIELD_DOCK_SWIPE_FLAVOR), CFIndex(GRABBY_FLAVOR_DOCK_PRIMARY))
        setFloat(hidEvent, UInt32(GRABBY_HID_FIELD_DOCK_SWIPE_PROGRESS), progress)
        // Real trackpad events flag the swipe direction exactly once, early in the gesture.
        if phase == .changed, !maskSent, abs(progress) >= DockSwipeEngine.maskThreshold {
            maskSent = true
            let mask: CFIndex = axis == .horizontal ? (progress < 0 ? 4 : 8) : (progress < 0 ? 1 : 2)
            setInt(hidEvent, UInt32(GRABBY_HID_FIELD_DOCK_SWIPE_MASK), mask)
        }

        if phase == .ended || phase == .cancelled,
           let child = create(kCFAllocatorDefault, UInt32(GRABBY_HID_TYPE_VELOCITY), mach_absolute_time(), 0) {
            let childEvent = child.takeRetainedValue()
            setFloat(childEvent, UInt32(GRABBY_HID_FIELD_VELOCITY_X), exitSpeed)
            setFloat(childEvent, UInt32(GRABBY_HID_FIELD_VELOCITY_Y), exitSpeed)
            setFloat(childEvent, UInt32(GRABBY_HID_FIELD_VELOCITY_Z), 0)
            append(hidEvent, childEvent, 0)
        }

        guard let wrapper = CGEvent(source: nil),
              let type = CGEventType(rawValue: UInt32(GRABBY_CGEVENT_TYPE_GESTURE_WRAPPER)) else { return nil }
        wrapper.type = type
        attach(wrapper, hidEvent)
        return wrapper
    }
}
