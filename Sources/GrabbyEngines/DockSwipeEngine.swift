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

    private let api: grabby_private_api
    private let fakeFailure: Bool
    private let queue = DispatchQueue(label: "com.pixelstwo.grabby.dockswipe")
    private var resends: [DispatchWorkItem] = []

    public init(api: grabby_private_api,
                fakeFailure: Bool = ProcessInfo.processInfo.environment["GRABBY_FAKE_SMOOTH_FAILURE"] == "1") {
        self.api = api
        self.fakeFailure = fakeFailure
    }

    public var available: Bool {
        api.IOHIDEventCreate != nil && api.IOHIDEventSetIntegerValue != nil && api.IOHIDEventSetFloatValue != nil
            && api.IOHIDEventAppendEvent != nil && api.SLEventSetIOHIDEvent != nil
    }

    /// Returns false on a hard failure (missing symbol or event creation failure).
    @discardableResult
    public func post(axis: Axis, phase: Phase, progress: Double, exitSpeed: Double = 0) -> Bool {
        if phase == .began { cancelResends() }
        if fakeFailure {
            Log.engine.debug("DockSwipeEngine: GRABBY_FAKE_SMOOTH_FAILURE set, posting nothing")
            return true
        }
        guard available else { return false }
        guard let event = makeEvent(axis: axis, phase: phase, progress: progress, exitSpeed: exitSpeed) else {
            return false
        }
        event.post(tap: .cgSessionEventTap)
        Log.engine.debug("DockSwipeEngine: \(axis == .horizontal ? "h" : "v") phase=\(phase.bits) progress=\(progress, format: .fixed(precision: 4))")

        if phase == .ended || phase == .cancelled {
            // The end event is occasionally dropped under load; resend it so the transition never sticks.
            for delay in DockSwipeEngine.resendDelays {
                let item = DispatchWorkItem { [weak self] in
                    guard let self, let again = self.makeEvent(axis: axis, phase: phase, progress: progress, exitSpeed: exitSpeed) else { return }
                    again.post(tap: .cgSessionEventTap)
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

    private func makeEvent(axis: Axis, phase: Phase, progress: Double, exitSpeed: Double) -> CGEvent? {
        guard let create = api.IOHIDEventCreate, let setInt = api.IOHIDEventSetIntegerValue,
              let setFloat = api.IOHIDEventSetFloatValue, let append = api.IOHIDEventAppendEvent,
              let attach = api.SLEventSetIOHIDEvent else { return nil }

        let options = phase.bits << UInt32(GRABBY_PHASE_SHIFT)
        guard let hid = create(kCFAllocatorDefault, UInt32(GRABBY_HID_TYPE_DOCK_SWIPE), 0, options) else { return nil }
        let hidEvent = hid.takeRetainedValue()
        let motion = axis == .horizontal ? GRABBY_DOCK_SWIPE_HORIZONTAL : GRABBY_DOCK_SWIPE_VERTICAL
        setInt(hidEvent, UInt32(GRABBY_HID_FIELD_DOCK_SWIPE_MOTION), CFIndex(motion))
        setInt(hidEvent, UInt32(GRABBY_HID_FIELD_DOCK_SWIPE_FLAVOR), CFIndex(GRABBY_FLAVOR_DOCK_PRIMARY))
        setFloat(hidEvent, UInt32(GRABBY_HID_FIELD_DOCK_SWIPE_PROGRESS), progress)

        if phase == .ended || phase == .cancelled,
           let child = create(kCFAllocatorDefault, UInt32(GRABBY_HID_TYPE_VELOCITY), 0, 0) {
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
