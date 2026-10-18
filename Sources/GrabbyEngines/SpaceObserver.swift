import ColorSync
import CoreGraphics
import Foundation
import GrabbyCore
import GrabbyPrivate

/// Reads the active Space, the Space count for the display under the pointer, and that display's size.
/// Uses CoreGraphics only so it is safe to call from the tap thread.
public final class SpaceObserver: SpaceReader, @unchecked Sendable {
    private let api: grabby_private_api

    public init(api: grabby_private_api) {
        self.api = api
    }

    public func refreshInterval() -> Duration {
        let rate = CGDisplayCopyDisplayMode(displayUnderPointer())?.refreshRate ?? 0
        let hz = rate > 1 ? rate : 60
        return .nanoseconds(Int64(1_000_000_000 / hz))
    }

    /// Mission Control puts up Dock-owned windows that cover the display; nothing else does.
    public func missionControlIsActive() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let bounds = CGDisplayBounds(displayUnderPointer())
        for w in list where (w[kCGWindowOwnerName as String] as? String) == "Dock" {
            guard let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = b["Width"], let height = b["Height"] else { continue }
            if width >= bounds.width * 0.9 && height >= bounds.height * 0.9 {
                Trace.log("mission control active: Dock window \(width)x\(height) layer=\(w[kCGWindowLayer as String] ?? "?")")
                return true
            }
        }
        return false
    }

    public func activeSpace() -> UInt64 {
        guard let cid = api.CGSMainConnectionID, let active = api.CGSGetActiveSpace else { return 0 }
        return active(cid())
    }

    public func spaceCount(onDisplayUnderPointer: Bool) -> Int {
        guard let cid = api.CGSMainConnectionID, let copy = api.CGSCopyManagedDisplaySpaces else { return 1 }
        let display = onDisplayUnderPointer ? displayUnderPointer() : CGMainDisplayID()
        guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() else { return 1 }
        let uuid = CFUUIDCreateString(nil, uuidRef) as String
        guard let array = copy(cid())?.takeRetainedValue() as? [[String: Any]] else { return 1 }
        for entry in array {
            if let id = entry["Display Identifier"] as? String, id == uuid || (id == "Main" && display == CGMainDisplayID()) {
                let n = max(1, (entry["Spaces"] as? [Any])?.count ?? 1)
                Trace.log("spaces display=\(id) count=\(n)")
                return n
            }
        }
        Trace.log("spaces no match for display \(uuid); identifiers=\(array.compactMap { $0["Display Identifier"] as? String })")
        return 1
    }

    /// Human-readable dump of what macOS reports, for the probe.
    public func describeDisplays() -> String {
        guard let cid = api.CGSMainConnectionID, let copy = api.CGSCopyManagedDisplaySpaces,
              let array = copy(cid())?.takeRetainedValue() as? [[String: Any]] else { return "unavailable" }
        var out = "pointer display: \(displayUnderPointer()) main: \(CGMainDisplayID()) bounds: \(CGDisplayBounds(displayUnderPointer()))\n"
        if let u = CGDisplayCreateUUIDFromDisplayID(displayUnderPointer())?.takeRetainedValue() {
            out += "pointer display uuid: \(CFUUIDCreateString(nil, u) as String)\n"
        }
        for entry in array {
            let id = entry["Display Identifier"] as? String ?? "?"
            let spaces = (entry["Spaces"] as? [[String: Any]]) ?? []
            out += "display \(id): \(spaces.count) spaces, current=\((entry["Current Space"] as? [String: Any])?["id64"] ?? "?")\n"
        }
        return out
    }

    public func screenSize() -> Size {
        let bounds = CGDisplayBounds(displayUnderPointer())
        return Size(width: bounds.width, height: bounds.height)
    }

    private func displayUnderPointer() -> CGDirectDisplayID {
        guard let location = CGEvent(source: nil)?.location else { return CGMainDisplayID() }
        var id: CGDirectDisplayID = 0
        var count: UInt32 = 0
        if CGGetDisplaysWithPoint(location, 1, &id, &count) == .success, count > 0 {
            return id
        }
        return CGMainDisplayID()
    }
}
