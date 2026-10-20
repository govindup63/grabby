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
    private let trail = TrailOverlay()
    private var onboardingShown = false
    private let inspector = GestureInspector()
    private var inspectorStarted = false
    private lazy var onboarding = OnboardingWindowController()
    private var conflictTimer: Timer?
    /// Only ever touched on the tap thread after construction.
    nonisolated(unsafe) private var controller: GestureController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = makeStore()
        settings = store.load()
        Log.settings.info("Loaded settings: button=\(self.settings.actionButton.map(String.init) ?? "nil")")

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
        comboTap = ComboTap(thread: tapThread)
        buttonTap.actionButton = settings.actionButton

        spaces = SpaceObserver(api: privateAPI)
        hotkeys = HotkeyEngine(api: privateAPI)
        dock = DockSwipeEngine(api: privateAPI)
        output = EngineOutput(dock: dock, hotkeys: hotkeys) { [weak self] in
            Log.engine.error("Smooth engine hard failure, switching this gesture to the keyboard path")
            self?.controller.reportHardError()
        }
        controller = GestureController(settings: settings, smoothAvailable: smoothAvailable, clock: MonotonicClock(),
                                       output: output, spaces: spaces, notifier: notifier)
        controller.onTrace = { Trace.log($0) }
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
            tapThread.sync { [controller, moveTap, comboTap] in
                controller?.cancelGesture()
                moveTap?.setEnabled(false)
                comboTap?.setEnabled(false)
            }
        }
        buttonTap?.destroy()
        moveTap?.destroy()
        comboTap?.destroy()
    }

    /// Settings changed in the UI: persist is done by the model; push to the taps and the controller.
    private func apply(_ updated: Settings) {
        settings = updated
        buttonTap.actionButton = updated.actionButton
        tapThread.async { [controller] in controller?.settings = updated }
        Log.settings.info("Applied settings: button=\(updated.actionButton.map(String.init) ?? "nil") tap=\(updated.tapAction.rawValue)")
    }

    /// All three closures run on the tap thread, which is the only thread that drives the controller.
    private func wireTaps() {
        let controller = self.controller!
        let moveTap = self.moveTap!
        let comboTap = self.comboTap!
        let trail = self.trail
        buttonTap.onDown = { location in
            moveTap.setEnabled(true)
            comboTap.setEnabled(true)
            controller.actionButtonDown(at: Point(x: location.x, y: location.y))
            if controller.settings.showTrail {
                trail.record(location)
                DispatchQueue.main.async { trail.begin() }
            }
        }
        comboTap.onClick = { button in
            controller.comboClick(button == .left ? .left : .right)
        }
        moveTap.onMove = { dx, dy, location in
            controller.pointerMoved(dx: dx, dy: dy)
            if controller.settings.showTrail { trail.record(location) }
        }
        let spaces = self.spaces!
        let tapThread = self.tapThread
        buttonTap.onUp = { [weak self] in
            controller.actionButtonUp()
            moveTap.setEnabled(false)
            comboTap.setEnabled(false)
            DispatchQueue.main.async { trail.end() }
            if controller.lastTapWasPassThrough, let button = controller.settings.actionButton {
                self?.replayClick(button: button)
            }
            if controller.awaitingVerification {
                tapThread.after(0.4) {
                    controller.verifySmoothGesture(spaceAfter: spaces.activeSpace())
                    Log.gesture.debug("Verified smooth gesture, sticky=\(controller.stickyFallback)")
                }
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
                tapsReady = buttonTap.create() && moveTap.create() && comboTap.create()
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
                tapThread.async { [controller, moveTap, comboTap] in
                    controller?.cancelGesture()
                    moveTap?.setEnabled(false)
                    comboTap?.setEnabled(false)
                }
            }
            statusItem.setStatus("Needs Accessibility access")
            settingsModel.status = "Needs Accessibility access"
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
