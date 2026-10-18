import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let window: NSWindow
    var onAppear: (() -> Void)?

    init(model: SettingsModel) {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        window = NSWindow(contentViewController: hosting)
        window.title = "Grabby"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        onAppear?()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
