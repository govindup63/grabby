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
        engine = .none
        handle(recognizer.buttonDown())
    }

    public func pointerMoved(dx: Double, dy: Double) {
        handle(recognizer.move(dx: dx, dy: dy))
    }

    public func actionButtonUp() {
        handle(recognizer.buttonUp())
    }

    public func cancelGesture() {
        handle(recognizer.cancel())
    }

    public func verifySmoothGesture(spaceAfter: UInt64) {
        // Completed in User Story 4.
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

    private var useSmooth: Bool {
        settings.switchingStyle == .smooth && smoothAvailable && !stickyFallback
    }

    private func begin(_ axis: Axis) {
        let distance = recognizer.distance
        let down = axis == .vertical && distance > 0
        if down && settings.dragDownAction == .none {
            engine = .none
            return
        }
        let keyboardOnly = down && settings.dragDownAction == .showDesktop
        if useSmooth && !keyboardOnly {
            let userNatural = settings.naturalDirection ?? systemNaturalDirection
            let scaler = SwipeProgressScaler(screen: spaces.screenSize(),
                                             spaceCount: spaces.spaceCount(onDisplayUnderPointer: true),
                                             naturalDirection: userNatural != systemNaturalDirection)
            var coalescer = EventCoalescer(clock: clock)
            let initial = progress(for: distance, axis: axis, scaler: scaler)
            let sent = coalescer.began(progress: initial)
            spaceBefore = spaces.activeSpace()
            engine = .smooth(scaler, coalescer, axis)
            output.dockSwipeBegan(axis: axis, progress: sent)
        } else {
            var stepper = DiscreteStepper(axis: axis, dragDownAction: settings.dragDownAction)
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
        switch engine {
        case .smooth(let scaler, var coalescer, let axis):
            let p = progress(for: delta, axis: axis, scaler: scaler)
            let sent = coalescer.changed(delta: p)
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
        if case .smooth(_, let coalescer, _) = engine {
            let offset = coalescer.flushForEnd()
            let speed = EndPhaseDecider.exitSpeed(lastDelta: coalescer.lastDelta)
            let phase: EndPhase = cancel ? .cancelled
                : EndPhaseDecider.phase(lastDelta: coalescer.lastDelta, originOffset: offset)
            switch phase {
            case .ended: output.dockSwipeEnded(progress: offset, exitSpeed: speed)
            case .cancelled: output.dockSwipeCancelled(progress: offset, exitSpeed: speed)
            }
        }
        if pinned {
            pointer.unpin()
            pinned = false
        }
        engine = .none
    }

    private func progress(for delta: Double, axis: Axis, scaler: SwipeProgressScaler) -> Double {
        switch axis {
        case .horizontal: return scaler.horizontalProgress(forDelta: delta)
        case .vertical: return scaler.verticalProgress(forDelta: delta)
        }
    }
}
