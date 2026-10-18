import Foundation
import ServiceManagement

/// Wraps SMAppService for the main app bundle. Only works when running from a signed .app bundle.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var status: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "Enabled"
        case .notRegistered: return "Not registered"
        case .requiresApproval: return "Waiting for approval in System Settings > General > Login Items"
        case .notFound: return "Not available (run Grabby from the built app bundle)"
        @unknown default: return "Unknown"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
