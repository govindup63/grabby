import AppKit
import GrabbyCore
import GrabbyEngines
import GrabbyPrivate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Grabby", isDirectory: true).appendingPathComponent("settings.json")
    }()

    private(set) var store: SettingsStore!
    private(set) var settings = Settings.defaults
    private(set) var privateAPI = grabby_private_resolve()
    private(set) var smoothAvailable = false

    let tapThread = TapThread()
    private(set) var buttonTap: ButtonTap!
    private(set) var moveTap: MoveTap!
    private var statusItem: StatusItemController!
    private let permissions = Permissions()
    private var tapsReady = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = makeStore()
        settings = store.load()
        Log.settings.info("Loaded settings: button=\(self.settings.actionButton.map(String.init) ?? "nil") style=\(self.settings.switchingStyle.rawValue)")

        smoothAvailable = withUnsafePointer(to: &privateAPI) { grabby_private_all_present($0) }
        for i in 0..<Int(GRABBY_PRIVATE_SYMBOL_COUNT) where !withUnsafePointer(to: &privateAPI, { grabby_private_symbol_present($0, Int32(i)) }) {
            Log.engine.error("Private symbol missing: \(String(cString: grabby_private_symbol_name(Int32(i))))")
        }
        Log.engine.info("Smooth engine available: \(self.smoothAvailable)")

        _ = tapThread.runLoop
        buttonTap = ButtonTap(thread: tapThread)
        moveTap = MoveTap(thread: tapThread)
        buttonTap.actionButton = settings.actionButton

        statusItem = StatusItemController()

        permissions.startPolling { [weak self] granted in
            self?.accessChanged(granted)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        buttonTap?.destroy()
        moveTap?.destroy()
    }

    private func accessChanged(_ granted: Bool) {
        if granted {
            if !tapsReady {
                tapsReady = buttonTap.create() && moveTap.create()
            }
            buttonTap.setEnabled(true)
            statusItem.setStatus(tapsReady ? "Grabby is working" : "Could not start event taps")
            Log.permission.info("Access granted, taps ready: \(self.tapsReady)")
        } else {
            buttonTap.setEnabled(false)
            tapThread.async { [moveTap] in moveTap?.setEnabled(false) }
            statusItem.setStatus("Needs Accessibility access")
            Log.permission.error("Accessibility access missing")
        }
    }

    private func makeStore() -> SettingsStore {
        let url = settingsURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: url), (try? JSONDecoder().decode(Settings.self, from: data)) == nil {
            let broken = url.appendingPathExtension("broken")
            try? FileManager.default.removeItem(at: broken)
            try? FileManager.default.moveItem(at: url, to: broken)
            Log.settings.error("settings.json was undecodable, moved to settings.json.broken")
        }
        return SettingsStore(
            read: { try? Data(contentsOf: url) },
            write: { try $0.write(to: url, options: .atomic) }
        )
    }
}
