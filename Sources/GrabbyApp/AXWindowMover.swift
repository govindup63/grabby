import AppKit
import ApplicationServices
import GrabbyCore
import GrabbyEngines

/// Moves the window under the pointer through the Accessibility API, the way three-finger drag does.
/// Called from the tap thread; position writes are coalesced to one per 8 ms and flushed on release.
final class AXWindowMover: WindowMover, @unchecked Sendable {
    private static let messagingTimeout: Float = 0.05
    private static let interval: UInt64 = 8_000_000  // ns

    private var window: AXUIElement?
    private var position = CGPoint.zero
    private var dirty = false
    private var lastWrite: UInt64 = 0

    func grabWindow(at point: Point) -> Bool {
        releaseWindow()
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, AXWindowMover.messagingTimeout)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit) == .success,
              let element = hit, let target = enclosingWindow(of: element) else {
            Log.gesture.debug("AXWindowMover: no window under pointer")
            return false
        }
        AXUIElementSetMessagingTimeout(target, AXWindowMover.messagingTimeout)
        guard let current = readPosition(of: target) else {
            Log.gesture.debug("AXWindowMover: window has no readable position")
            return false
        }
        window = target
        position = current
        dirty = false
        raise(target)
        Log.gesture.debug("AXWindowMover: grabbed window at \(current.x),\(current.y)")
        return true
    }

    func moveGrabbedWindow(dx: Double, dy: Double) {
        guard window != nil else { return }
        position.x += dx
        position.y += dy
        dirty = true
        let now = DispatchTime.now().uptimeNanoseconds
        if now - lastWrite >= AXWindowMover.interval {
            flush()
            lastWrite = now
        }
    }

    func releaseWindow() {
        if window != nil {
            flush()
            Log.gesture.debug("AXWindowMover: released window at \(self.position.x),\(self.position.y)")
        }
        window = nil
        dirty = false
    }

    private func flush() {
        guard dirty, let window else { return }
        var point = position
        if let value = AXValueCreate(.cgPoint, &point) {
            let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
            if result != .success {
                Log.gesture.error("AXWindowMover: set position failed (\(result.rawValue))")
            }
        }
        dirty = false
    }

    private func enclosingWindow(of element: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &ref) == .success, let ref {
            return (ref as! AXUIElement)
        }
        // Walk up the parents until a window role appears.
        var current: AXUIElement? = element
        for _ in 0..<20 {
            guard let node = current else { return nil }
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(node, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String, role == kAXWindowRole {
                return node
            }
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(node, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parent = parentRef else { return nil }
            current = (parent as! AXUIElement)
        }
        return nil
    }

    private func readPosition(of window: AXUIElement) -> CGPoint? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &ref) == .success, let ref else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(ref as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func raise(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        var pid: pid_t = 0
        if AXUIElementGetPid(window, &pid) == .success {
            DispatchQueue.main.async {
                NSRunningApplication(processIdentifier: pid)?.activate()
            }
        }
    }
}
