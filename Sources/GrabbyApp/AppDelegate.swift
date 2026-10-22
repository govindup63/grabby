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
    private(set) var comboTap: ComboTap!
    private(set) var buttonStateTap: ButtonStateTap!
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
    /// Built on first use: SwiftUI windows cost tens of megabytes and most launches never open them.
    private lazy var settingsWindow: SettingsWindowController = {
        let w = SettingsWindowController(model: settingsModel)
        w.onAppear = { [weak self] in self?.refreshConflicts() }
        return w
    }()
    private var settingsWindowBuilt = false
    private var onboardingShown = false
    private var accessRequested = false
    private let inspector = GestureInspector()
    private var inspectorStarted = false
    private lazy var onboarding = OnboardingWindowController()
    private var conflictTimer: Timer?
    /// Only ever touched on the bridge's gesture queue after construction.
    nonisolated(unsafe) private var controller: GestureController!
    private var bridge: GestureBridge!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = makeStore()
        settings = store.load()
        Log.settings.info("Loaded settings: button=\(self.settings.actionButton.map(String.init) ?? "nil")")

        dock = DockSwipeEngine(api: privateAPI)
        smoothAvailable = dock.available
        Log.engine.info("Dock Swipe format: \(String(describing: self.dock.format))")
        for i in 0..<Int(GRABBY_PRIVATE_SYMBOL_COUNT) where !withUnsafePointer(to: &privateAPI, { grabby_private_symbol_present($0, Int32(i)) }) {
            Log.engine.error("Private symbol missing: \(String(cString: grabby_private_symbol_name(Int32(i))))")
        }
        Log.engine.info("Smooth engine available: \(self.smoothAvailable)")

        statusItem = StatusItemController()
        notifier = MenuBarNotifier(statusItem: statusItem)

        _ = tapThread.runLoop
        buttonTap = ButtonTap(thread: tapThread)
        moveTap = MoveTap(thread: tapThread)
        comboTap = ComboTap(thread: tapThread)
        buttonStateTap = ButtonStateTap(thread: tapThread)
        buttonTap.actionButton = settings.actionButton

        spaces = SpaceObserver(api: privateAPI)
        hotkeys = HotkeyEngine(api: privateAPI)
        output = EngineOutput(dock: dock, hotkeys: hotkeys) { [weak self] in
            Log.engine.error("Smooth engine hard failure, switching this gesture to the keyboard path")
            self?.controller.reportHardError()
        }
        controller = GestureController(settings: settings, smoothAvailable: smoothAvailable, format: dock.format, clock: MonotonicClock(),
                                       output: output, spaces: spaces, notifier: notifier)
        controller.onTrace = { Trace.log($0) }
        controller.systemNaturalDirection = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
        dock.naturalDirection = settings.naturalDirection ?? controller.systemNaturalDirection
        wireTaps()

        settingsModel = SettingsModel(settings: settings, store: store) { [weak self] updated in
            self?.apply(updated)
        }
        settingsModel.onLearnStart = { [weak self] in self?.buttonTap.setEnabled(false) }
        settingsModel.onLearnEnd = { [weak self] in
            guard let self else { return }
            self.buttonTap.setEnabled(self.hasAccess)
        }
        statusItem.onOpenSettings = { [weak self] in self?.showSettings() }

        permissions.startPolling { [weak self] granted in
            self?.accessChanged(granted)
        }

        if settings.actionButton == nil && hasAccess {
            showSettings()
        }
    }

    private func showSettings() {
        settingsWindowBuilt = true
        settingsWindow.show()
    }

    private func refreshConflicts() {
        settingsModel.conflicts = ConflictDetector.conflicts(actionButton: settings.actionButton)
        conflictTimer?.invalidate()
        conflictTimer = nil
        guard settingsWindowBuilt, settingsWindow.isVisible else { return }
        conflictTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refreshConflicts() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if tapsReady {
            bridge.cancel(sync: true)
        }
        buttonTap?.destroy()
        moveTap?.destroy()
        comboTap?.destroy()
        buttonStateTap?.destroy()
    }

    /// Settings changed in the UI: persist is done by the model; push to the taps and the controller.
    private func apply(_ updated: Settings) {
        settings = updated
        buttonTap.actionButton = updated.actionButton
        dock.naturalDirection = updated.naturalDirection ?? controller.systemNaturalDirection
        bridge.apply(updated)
        Log.settings.info("Applied settings: button=\(updated.actionButton.map(String.init) ?? "nil") tap=\(updated.tapAction.rawValue)")
    }

    private func wireTaps() {
        let bridge = GestureBridge(controller: controller, spaces: spaces, moveTap: moveTap, comboTap: comboTap)
        self.bridge = bridge
        let buttonState = self.buttonStateTap!
        buttonTap.otherButtonHeld = { buttonState.anyPrimaryButtonDown }
        buttonTap.onDown = { location in bridge.buttonDown(at: location) }
        moveTap.target = bridge
        comboTap.onClick = { button in bridge.click(button) }
        buttonTap.onUp = { bridge.buttonUp() }
    }

    private func accessChanged(_ granted: Bool) {
        hasAccess = granted
        if granted {
            if !tapsReady {
                tapsReady = buttonTap.create() && moveTap.create() && comboTap.create() && buttonStateTap.create()
            }
            buttonTap.setEnabled(true)
            if !inspectorStarted { inspectorStarted = inspector.start() }
            let text = tapsReady ? "Grabby is working" : "Could not start event taps"
            statusItem.setStatus(text)
            settingsModel.status = text
            if onboardingShown { onboarding.close() }
            if settings.actionButton == nil { showSettings() }
            Log.permission.info("Access granted, taps ready: \(self.tapsReady)")
        } else {
            buttonTap.setEnabled(false)
            if tapsReady {
                bridge.cancel(sync: false)
            }
            statusItem.setStatus("Needs Accessibility access")
            settingsModel.status = "Needs Accessibility access"
            if !accessRequested {
                accessRequested = true
                Permissions.requestAccess()
            }
            onboardingShown = true
            onboarding.show()
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
