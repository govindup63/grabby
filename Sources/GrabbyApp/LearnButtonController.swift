import AppKit
import CoreGraphics
import GrabbyCore
import GrabbyEngines

/// Listens for one mouse button press with a listen-only tap on the main run loop.
@MainActor
final class LearnButtonController {
    var onOutcome: ((LearnButtonSession.Outcome) -> Void)?

    private var session: LearnButtonSession?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private let clock = MonotonicClock()

    var isListening: Bool { session != nil }

    func start() {
        stop()
        let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cghidEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                           eventsOfInterest: mask, callback: learnTapCallback, userInfo: info) else {
            Log.tap.error("LearnButtonController: could not create listen tap")
            onOutcome?(.rejected(reason: "Grabby needs Accessibility access before it can learn a button."))
            return
        }
        tap = port
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        session = LearnButtonSession.start(at: clock.now())
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        Log.tap.info("LearnButtonController: listening")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let src = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        source = nil
        tap = nil
        session = nil
    }

    private func tick() {
        guard session != nil else { return }
        let outcome = session!.tick(now: clock.now())
        switch outcome {
        case .waiting: break
        case .timedOut:
            stop()
            onOutcome?(.timedOut)
        default:
            stop()
        }
    }

    fileprivate func pressed(button: Int) {
        guard session != nil else { return }
        let outcome = session!.buttonPressed(number: button, at: clock.now())
        switch outcome {
        case .learned:
            stop()
            onOutcome?(outcome)
        case .rejected:
            onOutcome?(outcome)
        case .waiting, .timedOut, .finished:
            break
        }
    }
}

private func learnTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<LearnButtonController>.fromOpaque(userInfo).takeUnretainedValue()
    let button: Int
    switch type {
    case .leftMouseDown: button = 0
    case .rightMouseDown: button = 1
    case .otherMouseDown: button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
    default: return Unmanaged.passUnretained(event)
    }
    if GrabbyEventSource.isOwnEvent(event) { return Unmanaged.passUnretained(event) }
    MainActor.assumeIsolated {
        controller.pressed(button: button)
    }
    return Unmanaged.passUnretained(event)
}
