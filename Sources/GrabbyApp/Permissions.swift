import AppKit
import CoreGraphics
import GrabbyEngines

@MainActor
final class Permissions {
    private var timer: Timer?
    private(set) var hasAccess = false

    /// Creating a filtering tap is the reliable check; AXIsProcessTrusted can stay true after revocation.
    nonisolated static func checkAccess() -> Bool {
        let mask: CGEventMask = 1 << CGEventType.otherMouseDown.rawValue
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .tailAppendEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, _, event, _ in
                                              Unmanaged.passUnretained(event)
                                          }, userInfo: nil) else {
            return false
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        return true
    }

    nonisolated static func openAccessibilityPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Polls every second while access is missing and every five seconds while present.
    func startPolling(onChange: @escaping @MainActor (Bool) -> Void) {
        hasAccess = Permissions.checkAccess()
        onChange(hasAccess)
        schedule(onChange: onChange)
    }

    private func schedule(onChange: @escaping @MainActor (Bool) -> Void) {
        timer?.invalidate()
        let interval: TimeInterval = hasAccess ? 5 : 1
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Permissions.checkAccess()
                if now != self.hasAccess {
                    self.hasAccess = now
                    Log.permission.info("Accessibility access changed: \(now)")
                    onChange(now)
                }
                self.schedule(onChange: onChange)
            }
        }
    }
}
