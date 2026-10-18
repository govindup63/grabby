import AppKit

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let statusLine = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    var onOpenSettings: (() -> Void)?
    var onExperiment: ((String) -> Void)?

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "Grabby")
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let expA = NSMenuItem(title: "Debug: slide test A (SkyLight)", action: #selector(runA), keyEquivalent: "")
        expA.target = self
        menu.addItem(expA)
        let expB = NSMenuItem(title: "Debug: slide test B (poke)", action: #selector(runB), keyEquivalent: "")
        expB.target = self
        menu.addItem(expB)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Grabby", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
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

    @objc private func runA() { onExperiment?("skyLight") }
    @objc private func runB() { onExperiment?("poke") }

    @objc private func openSettings() {
        onOpenSettings?()
    }
}
