import AppKit
import GrabbyCore

/// A transparent, click-through window over every display that draws a glowing line behind the
/// pointer while the action button is held. Points arrive from the tap thread; drawing happens on
/// the main thread at 60 Hz only while there is something to draw.
@MainActor
final class TrailOverlay {
    private let window: NSWindow
    private let view = TrailView()
    private let inbox = PointInbox()
    private var trail = CursorTrail()
    private var timer: Timer?
    private var holding = false
    private let clock = MonotonicClock()

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.contentView = view
    }

    /// Called from any thread with a pointer location in CoreGraphics (top-left origin) coordinates.
    nonisolated func record(_ location: CGPoint) {
        inbox.add(location, at: clock.now())
    }

    func begin() {
        holding = true
        let frame = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        window.setFrame(frame, display: false)
        view.frame = CGRect(origin: .zero, size: frame.size)
        window.orderFrontRegardless()
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

    private func tick() {
        let now = clock.now()
        let drained = inbox.drain()
        if holding {
            for (p, t) in drained { trail.append(Point(x: p.x, y: p.y), at: t) }
        }
        let segments = trail.segments(now: now)
        view.segments = segments.map { seg in
            TrailView.Line(from: convert(seg.from), to: convert(seg.to), alpha: seg.alpha)
        }
        view.needsDisplay = true
        if !holding && segments.isEmpty {
            timer?.invalidate()
            timer = nil
            trail.clear()
            _ = inbox.drain()
            window.orderOut(nil)
        }
    }

    /// CoreGraphics global (top-left origin) to this window's view coordinates (bottom-left origin).
    private func convert(_ p: Point) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let screenPoint = CGPoint(x: p.x, y: primaryHeight - p.y)
        return CGPoint(x: screenPoint.x - window.frame.minX, y: screenPoint.y - window.frame.minY)
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
        var alpha: Double
    }

    var segments: [Line] = []

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard !segments.isEmpty, let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        // The icon's palette: warm orange at the head, pink-red along the tail. Two passes: a wide
        // soft glow, then the crisp core line.
        for (width, glow) in [(CGFloat(14), true), (CGFloat(4), false)] {
            for line in segments {
                let t = CGFloat(line.alpha)
                let r: CGFloat = 1.0
                let g: CGFloat = 0.24 + 0.30 * t   // 0.24 (pink) to 0.54 (orange)
                let b: CGFloat = 0.47 - 0.23 * t   // 0.47 to 0.24
                let a: CGFloat = glow ? 0.28 * t : 0.95 * t
                ctx.setStrokeColor(CGColor(red: r, green: g, blue: b, alpha: a))
                ctx.setLineWidth(width * (0.6 + 0.4 * t))
                ctx.move(to: line.from)
                ctx.addLine(to: line.to)
                ctx.strokePath()
            }
        }
    }
}
