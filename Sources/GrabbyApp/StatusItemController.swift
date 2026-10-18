import AppKit

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let statusLine = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    var onOpenSettings: (() -> Void)?

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusItemController.menuBarImage()
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Grabby", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
    }

    /// The bundled template icon (follows the menu bar tint); the SF Symbol when run outside a bundle.
    private static func menuBarImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        return NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "Grabby")
    }

    func setStatus(_ text: String) {
        statusLine.title = text
    }

    /// Temporarily replaces the icon with a short text, used for the one-time fallback notice.
    func flash(_ text: String, seconds: TimeInterval) {
        item.length = NSStatusItem.variableLength
        item.button?.title = " " + text
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.item.button?.title = ""
            self?.item.length = NSStatusItem.squareLength
        }
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }
}
