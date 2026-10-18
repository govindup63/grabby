import AppKit
import CoreGraphics
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
    private var hasAccess = false

    private var spaces: SpaceObserver!
    private var hotkeys: HotkeyEngine!
    private var dock: DockSwipeEngine!
    private var output: EngineOutput!
    private var notifier: MenuBarNotifier!
    private var settingsModel: SettingsModel!
    private var settingsWindow: SettingsWindowController!
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

        settingsModel = SettingsModel(settings: settings, store: store) { [weak self] updated in
            self?.apply(updated)
        }
        settingsModel.onLearnStart = { [weak self] in self?.buttonTap.setEnabled(false) }
        settingsModel.onLearnEnd = { [weak self] in
            guard let self else { return }
            self.buttonTap.setEnabled(self.hasAccess)
        }
        settingsWindow = SettingsWindowController(model: settingsModel)
        statusItem.onOpenSettings = { [weak self] in self?.settingsWindow.show() }

        permissions.startPolling { [weak self] granted in
            self?.accessChanged(granted)
        }

        if settings.actionButton == nil {
            settingsWindow.show()
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

    /// Settings changed in the UI: persist is done by the model; push to the taps and the controller.
    private func apply(_ updated: Settings) {
        settings = updated
        buttonTap.actionButton = updated.actionButton
        tapThread.async { [controller] in controller?.settings = updated }
        Log.settings.info("Applied settings: button=\(updated.actionButton.map(String.init) ?? "nil") style=\(updated.switchingStyle.rawValue) tap=\(updated.tapAction.rawValue)")
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
        buttonTap.onUp = { [weak self] in
            controller.actionButtonUp()
            moveTap.setEnabled(false)
            if controller.lastTapWasPassThrough, let button = controller.settings.actionButton {
                self?.replayClick(button: button)
            }
        }
    }

    /// Posts the swallowed click again, tagged so ButtonTap lets it through.
    nonisolated private func replayClick(button: Int) {
        guard let location = CGEvent(source: nil)?.location else { return }
        let mouseButton = CGMouseButton(rawValue: UInt32(button)) ?? .center
        let source = GrabbyEventSource.shared
        guard let down = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: location, mouseButton: mouseButton),
              let up = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: location, mouseButton: mouseButton) else { return }
        down.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        up.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        Log.tap.debug("Replayed click for button \(button)")
    }

    private func accessChanged(_ granted: Bool) {
        hasAccess = granted
        if granted {
            if !tapsReady {
                tapsReady = buttonTap.create() && moveTap.create()
            }
            buttonTap.setEnabled(true)
            let text = tapsReady ? "Grabby is working" : "Could not start event taps"
            statusItem.setStatus(text)
            settingsModel.status = text
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
            settingsModel.status = "Needs Accessibility access"
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
