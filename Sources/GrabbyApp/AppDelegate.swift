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

    private var spaces: SpaceObserver!
    private var hotkeys: HotkeyEngine!
    private var dock: DockSwipeEngine!
    private var output: EngineOutput!
    private var notifier: MenuBarNotifier!
    /// Only ever touched on the tap thread after construction.
    nonisolated(unsafe) private var controller: GestureController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = makeStore()
        settings = store.load()
        Log.settings.info("Loaded settings: button=\(self.settings.actionButton.map(String.init) ?? "nil") style=\(self.settings.switchingStyle.rawValue)")

        smoothAvailable = withUnsafePointer(to: &privateAPI) { grabby_private_all_present($0) }
        for i in 0..<Int(GRABBY_PRIVATE_SYMBOL_COUNT) where !withUnsafePointer(to: &privateAPI, { grabby_private_symbol_present($0, Int32(i)) }) {
            Log.engine.error("Private symbol missing: \(String(cString: grabby_private_symbol_name(Int32(i))))")
        }
        Log.engine.info("Smooth engine available: \(self.smoothAvailable)")

        statusItem = StatusItemController()
        notifier = MenuBarNotifier(statusItem: statusItem)

        _ = tapThread.runLoop
        buttonTap = ButtonTap(thread: tapThread)
        moveTap = MoveTap(thread: tapThread)
        buttonTap.actionButton = settings.actionButton

        spaces = SpaceObserver(api: privateAPI)
        hotkeys = HotkeyEngine(api: privateAPI)
        dock = DockSwipeEngine(api: privateAPI)
        output = EngineOutput(dock: dock, hotkeys: hotkeys) {
            Log.engine.error("Smooth engine hard failure")
        }
        controller = GestureController(settings: settings, smoothAvailable: smoothAvailable, clock: MonotonicClock(),
                                       output: output, spaces: spaces, pointer: moveTap, notifier: notifier)
        controller.systemNaturalDirection = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
        wireTaps()

        permissions.startPolling { [weak self] granted in
            self?.accessChanged(granted)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if tapsReady {
            tapThread.sync { [controller, moveTap] in
                controller?.cancelGesture()
                moveTap?.setEnabled(false)
            }
        }
        buttonTap?.destroy()
        moveTap?.destroy()
    }

    /// All three closures run on the tap thread, which is the only thread that drives the controller.
    private func wireTaps() {
        let controller = self.controller!
        let moveTap = self.moveTap!
        buttonTap.onDown = { location in
            moveTap.setEnabled(true)
            controller.actionButtonDown(at: Point(x: location.x, y: location.y))
        }
        moveTap.onMove = { dx, dy in
            controller.pointerMoved(dx: dx, dy: dy)
        }
        buttonTap.onUp = {
            controller.actionButtonUp()
            moveTap.setEnabled(false)
        }
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
            if tapsReady {
                tapThread.async { [controller, moveTap] in
                    controller?.cancelGesture()
                    moveTap?.setEnabled(false)
                }
            }
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

struct MonotonicClock: GrabbyClock {
    func now() -> Duration {
        .nanoseconds(Int64(DispatchTime.now().uptimeNanoseconds))
    }
}

final class MenuBarNotifier: UserNotifier, @unchecked Sendable {
    private let statusItem: StatusItemController

    init(statusItem: StatusItemController) {
        self.statusItem = statusItem
    }

    func showFallbackNotice() {
        DispatchQueue.main.async { [statusItem] in
            MainActor.assumeIsolated {
                statusItem.flash("Smooth switching failed, using keyboard shortcuts until relaunch", seconds: 6)
            }
        }
    }
}
