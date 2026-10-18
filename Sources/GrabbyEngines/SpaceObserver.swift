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
                return max(1, (entry["Spaces"] as? [Any])?.count ?? 1)
            }
        }
        return 1
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
