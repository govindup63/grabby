import Foundation

/// Drives one action-button gesture from recognizer events to engine calls.
/// Not internally synchronized: the app calls it from the tap thread only, hence `@unchecked Sendable`.
public final class GestureController: @unchecked Sendable {
    public var settings: Settings
    /// The system's own natural-scrolling setting; the user's override is applied relative to it,
    /// because macOS 27 applies the system setting to Dock Swipes by itself.
    public var systemNaturalDirection = true
    public private(set) var stickyFallback = false
    public private(set) var lastTapWasPassThrough = false
    /// True after a smooth gesture ended normally, until `verifySmoothGesture` is called.
    public var awaitingVerification: Bool { pendingVerification != nil }
    /// Debug hook; the app routes it to its trace file.
    public var onTrace: ((String) -> Void)?

    private let smoothAvailable: Bool
    private let clock: any GrabbyClock
    private let output: any GestureOutput
    private let spaces: any SpaceReader
    private let pointer: any PointerPin
    private let notifier: any UserNotifier

    private enum Engine {
        case smooth(SwipeProgressScaler, EventCoalescer, Axis)
        case keyboard(DiscreteStepper)
        case none
    }

    private var recognizer = GestureRecognizer()
    private var origin = Point(x: 0, y: 0)
    private var engine: Engine = .none
    private var pinned = false
    private var spaceBefore: UInt64 = 0
    private var dragAxis: Axis = .horizontal
    private var dragDistance: Double = 0
    private var hardErrorThisGesture = false
    private var comboFired = false
    private var pendingVerification: (axis: Axis, progress: Double)?
    private var consecutiveFailures = 0
    private var noticeShown = false

    public init(settings: Settings, smoothAvailable: Bool, clock: any GrabbyClock,
                output: any GestureOutput, spaces: any SpaceReader,
                pointer: any PointerPin, notifier: any UserNotifier) {
        self.settings = settings
        self.smoothAvailable = smoothAvailable
        self.clock = clock
        self.output = output
        self.spaces = spaces
        self.pointer = pointer
        self.notifier = notifier
    }

    // MARK: Input

    public func actionButtonDown(at origin: Point) {
        self.origin = origin
        lastTapWasPassThrough = false
        hardErrorThisGesture = false
        comboFired = false
        engine = .none
        handle(recognizer.buttonDown())
    }

    /// A left or right click while the action button is held. Returns true when consumed.
    @discardableResult
    public func comboClick(_ button: ComboButton) -> Bool {
        guard recognizer.isHeld, !comboFired else { return false }
        comboFired = true
        if recognizer.isDragging {
            handle(recognizer.cancel())
        }
        output.perform(button == .left ? .screenshotSelection : .screenshotOptions)
        return true
    }

    public func pointerMoved(dx: Double, dy: Double) {
        handle(recognizer.move(dx: dx, dy: dy))
    }

    public func actionButtonUp() {
        let events = recognizer.buttonUp()
        if comboFired { return }  // the click already did the work; no tap action
        handle(events)
    }

    public func cancelGesture() {
        handle(recognizer.cancel())
    }

    /// Called about 400 ms after a smooth gesture ended, with the active Space read at that moment.
    public func verifySmoothGesture(spaceAfter: UInt64) {
        guard let pending = pendingVerification else { return }
        pendingVerification = nil
        record(FallbackObservation(axis: pending.axis, progress: pending.progress, spaceBefore: spaceBefore,
                                   spaceAfter: spaceAfter, hardError: false,
                                   consecutiveFailures: consecutiveFailures,
                                   naturalDirection: userNaturalDirection, dragDownAction: settings.dragDownAction))
    }

    /// The smooth engine could not post. Cancel the dock swipe, catch up, and finish the drag on the keyboard path.
    public func reportHardError() {
        guard case .smooth(_, let coalescer, let axis) = engine else { return }
        hardErrorThisGesture = true
        let offset = coalescer.flushForEnd()
        output.dockSwipeCancelled(progress: offset, exitSpeed: 0)
        record(FallbackObservation(axis: axis, progress: offset, spaceBefore: spaceBefore, spaceAfter: spaceBefore,
                                   hardError: true, consecutiveFailures: consecutiveFailures,
                                   naturalDirection: userNaturalDirection, dragDownAction: settings.dragDownAction))
        var stepper = DiscreteStepper(axis: axis, dragDownAction: settings.dragDownAction, naturalDirection: userNaturalDirection)
        _ = stepper.move(delta: dragDistance)  // the catch-up step already covered this distance
        engine = .keyboard(stepper)
    }

    // MARK: Dispatch

    private func handle(_ events: [GestureEvent]) {
        for event in events {
            switch event {
            case .tap: runTap()
            case .dragBegan(let axis): begin(axis)
            case .dragChanged(let delta): change(delta)
            case .dragEnded: end(cancel: false)
            case .dragCancelled: end(cancel: true)
            }
        }
    }

    private func runTap() {
        switch settings.tapAction {
        case .missionControl: output.perform(.missionControl)
        case .appExpose: output.perform(.appExpose)
        case .showDesktop: output.perform(.showDesktop)
        case .none: break
        case .passThrough: lastTapWasPassThrough = true
        }
    }

    private var userNaturalDirection: Bool {
        settings.naturalDirection ?? systemNaturalDirection
    }

    private var useSmooth: Bool {
        settings.switchingStyle == .smooth && smoothAvailable && !stickyFallback
    }

    private func begin(_ axis: Axis) {
        let distance = recognizer.distance
        dragAxis = axis
        dragDistance = distance
        let down = axis == .vertical && distance > 0
        if down && settings.dragDownAction == .none {
            engine = .none
            return
        }
        if down && settings.dragDownAction == .exitMissionControl && !spaces.missionControlIsActive() {
            onTrace?("drag down: Mission Control not open, nothing to do")
            engine = .none
            return
        }
        let keyboardOnly = down && settings.dragDownAction == .showDesktop
        onTrace?("engine=\(useSmooth && !keyboardOnly ? "smooth" : "keyboard") style=\(settings.switchingStyle) smoothAvailable=\(smoothAvailable) sticky=\(stickyFallback)")
        if useSmooth && !keyboardOnly {
            let scaler = SwipeProgressScaler(screen: spaces.screenSize(),
                                             spaceCount: spaces.spaceCount(onDisplayUnderPointer: true),
                                             naturalDirection: userNaturalDirection != systemNaturalDirection)
            var coalescer = EventCoalescer(clock: clock)
            onTrace?("begin axis=\(axis) distance=\(distance) screen=\(spaces.screenSize()) spaces=\(spaces.spaceCount(onDisplayUnderPointer: true)) oneSpace=\(scaler.offsetForOneSpace)")
            let sent = coalescer.began(progress: progress(for: distance, axis: axis, scaler: scaler))
            spaceBefore = spaces.activeSpace()
            engine = .smooth(scaler, coalescer, axis)
            output.dockSwipeBegan(axis: axis, progress: sent)
        } else {
            var stepper = DiscreteStepper(axis: axis, dragDownAction: settings.dragDownAction, naturalDirection: userNaturalDirection)
            let steps = stepper.move(delta: distance)
            engine = .keyboard(stepper)
            steps.forEach(output.perform)
        }
        if settings.pinPointer {
            pointer.pin(at: origin)
            pinned = true
        }
    }

    private func change(_ delta: Double) {
        dragDistance += delta
        onTrace?("move delta=\(delta) total=\(dragDistance)")
        switch engine {
        case .smooth(let scaler, var coalescer, let axis):
            let sent = coalescer.changed(delta: progress(for: delta, axis: axis, scaler: scaler))
            engine = .smooth(scaler, coalescer, axis)
            if let sent { output.dockSwipeChanged(progress: sent) }
        case .keyboard(var stepper):
            let steps = stepper.move(delta: delta)
            engine = .keyboard(stepper)
            steps.forEach(output.perform)
        case .none:
            break
        }
    }

    private func end(cancel: Bool) {
        if case .smooth(_, let coalescer, let axis) = engine {
            let offset = coalescer.flushForEnd()
            if cancel {
                onTrace?("end cancelled offset=\(offset)")
                output.dockSwipeCancelled(progress: offset, exitSpeed: 0)
            } else {
                let velocity = coalescer.velocity(now: clock.now())
                let speed = ReleaseDecider.exitSpeed(velocity: velocity, progress: offset, throwStrength: settings.throwStrength)
                onTrace?("end offset=\(offset) velocity=\(velocity) exitSpeed=\(speed)")
                output.dockSwipeEnded(progress: offset, exitSpeed: speed)
                if !hardErrorThisGesture {
                    pendingVerification = (axis, offset)
                }
            }
        }
        if pinned {
            pointer.unpin()
            pinned = false
        }
        engine = .none
    }

    private func record(_ observation: FallbackObservation) {
        let verdict = FallbackDecider.decide(observation)
        consecutiveFailures = verdict.failureCount
        if let step = verdict.catchUpStep { output.perform(step) }
        if verdict.becameSticky && !stickyFallback {
            stickyFallback = true
            if !noticeShown {
                noticeShown = true
                notifier.showFallbackNotice()
            }
        }
    }

    private func progress(for delta: Double, axis: Axis, scaler: SwipeProgressScaler) -> Double {
        switch axis {
        case .horizontal: return scaler.horizontalProgress(forDelta: delta)
        case .vertical: return scaler.verticalProgress(forDelta: delta)
        }
    }
}
