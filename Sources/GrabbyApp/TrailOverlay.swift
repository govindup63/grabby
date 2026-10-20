import AppKit
import GrabbyCore

/// Draws a glowing comet behind the pointer while the action button is held.
///
/// One transparent, click-through window per display, each exactly the size of its screen. A
/// single window spanning displays with different scale factors is rendered at one scale and
/// lands the drawing in the wrong place on the other display, so every screen gets its own.
/// Samples arrive from the tap thread through a locked inbox; the main thread redraws at 60 Hz
/// only while there is something to draw, then hides the windows.
@MainActor
final class TrailOverlay {
    private var overlays: [ScreenOverlay] = []
    private let inbox = PointInbox()
    private var trail = CursorTrail()
    private var timer: Timer?
    private var holding = false
    private let clock = MonotonicClock()

    /// Called from any thread with a pointer location in CoreGraphics (top-left origin) coordinates.
    nonisolated func record(_ location: CGPoint) {
        inbox.add(location, at: clock.now())
    }

    func begin() {
        holding = true
        rebuildOverlaysIfScreensChanged()
        overlays.forEach { $0.show() }
        if timer == nil {
            let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    func end() {
        holding = false
    }

    private func rebuildOverlaysIfScreensChanged() {
        let frames = NSScreen.screens.map(\.frame)
        if overlays.map(\.screenFrame) == frames { return }
        overlays.forEach { $0.hide() }
        overlays = NSScreen.screens.map { ScreenOverlay(screen: $0) }
    }

    private func tick() {
        let now = clock.now()
        let drained = inbox.drain()
        if holding {
            for (p, t) in drained { trail.append(Point(x: p.x, y: p.y), at: t) }
        }
        let segments = trail.segments(now: now)
        // CoreGraphics global (top-left origin) to AppKit global (bottom-left origin of the primary screen).
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let lines = segments.map { seg in
            TrailView.Line(from: CGPoint(x: seg.from.x, y: primaryHeight - seg.from.y),
                           to: CGPoint(x: seg.to.x, y: primaryHeight - seg.to.y),
                           alpha: seg.alpha)
        }
        overlays.forEach { $0.render(lines) }
        if !holding && segments.isEmpty {
            timer?.invalidate()
            timer = nil
            trail.clear()
            _ = inbox.drain()
            overlays.forEach { $0.hide() }
        }
    }
}

/// One click-through window covering one display.
@MainActor
private final class ScreenOverlay {
    let screenFrame: CGRect
    private let window: NSWindow
    private let view = TrailView()

    init(screen: NSScreen) {
        screenFrame = screen.frame
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        view.frame = CGRect(origin: .zero, size: screen.frame.size)
        window.contentView = view
    }

    func show() {
        window.setFrame(screenFrame, display: false)
        window.orderFrontRegardless()
    }

    func hide() {
        view.lines = []
        window.orderOut(nil)
    }

    /// Lines are in AppKit global coordinates; shift them into this window's own space.
    func render(_ lines: [TrailView.Line]) {
        let origin = screenFrame.origin
        view.lines = lines.map {
            TrailView.Line(from: CGPoint(x: $0.from.x - origin.x, y: $0.from.y - origin.y),
                           to: CGPoint(x: $0.to.x - origin.x, y: $0.to.y - origin.y),
                           alpha: $0.alpha)
        }
        view.needsDisplay = true
    }
}

/// Thread-safe hand-off of pointer samples from the tap thread to the main thread.
final class PointInbox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [(CGPoint, Duration)] = []

    func add(_ point: CGPoint, at time: Duration) {
        lock.withLock { items.append((point, time)) }
    }

    func drain() -> [(CGPoint, Duration)] {
        lock.withLock { defer { items.removeAll() }; return items }
    }
}

final class TrailView: NSView {
    struct Line {
        var from: CGPoint
        var to: CGPoint
        /// 1 at the pointer, 0 at the end of the tail.
        var alpha: Double
    }

    var lines: [Line] = []

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard !lines.isEmpty, let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        // A comet: wide, bright and orange at the head; thin, faint and pink at the tail.
        // Pass 1 is a soft halo, pass 2 the crisp core.
        for pass in 0..<2 {
            let glow = pass == 0
            for line in lines {
                let t = CGFloat(line.alpha)
                let eased = t * t
                let g: CGFloat = 0.24 + 0.30 * t
                let b: CGFloat = 0.47 - 0.23 * t
                ctx.setStrokeColor(CGColor(red: 1.0, green: g, blue: b, alpha: glow ? 0.22 * eased : 0.95 * eased))
                ctx.setLineWidth((glow ? 18 : 5) * (0.15 + 0.85 * t))
                ctx.move(to: line.from)
                ctx.addLine(to: line.to)
                ctx.strokePath()
            }
        }
    }
}
