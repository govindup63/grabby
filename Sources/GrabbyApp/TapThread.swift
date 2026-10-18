import Foundation

/// A thread with its own run loop. Event taps live here so UI work never stalls a callback.
final class TapThread: Thread, @unchecked Sendable {
    private let ready = DispatchSemaphore(value: 0)
    private var loop: CFRunLoop?

    var runLoop: CFRunLoop {
        if loop == nil {
            start()
            ready.wait()
        }
        return loop!
    }

    override init() {
        super.init()
        name = "com.pixelstwo.grabby.taps"
        qualityOfService = .userInteractive
    }

    override func main() {
        loop = CFRunLoopGetCurrent()
        // A dummy port keeps the run loop alive when no tap source is attached yet.
        let port = NSMachPort()
        RunLoop.current.add(port, forMode: .default)
        ready.signal()
        CFRunLoopRun()
    }

    /// Runs `block` on the tap thread and waits for it.
    func sync<T>(_ block: @escaping @Sendable () -> T) -> T {
        if Thread.current === self { return block() }
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: T?
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue) {
            result = block()
            done.signal()
        }
        CFRunLoopWakeUp(runLoop)
        done.wait()
        return result!
    }

    func async(_ block: @escaping @Sendable () -> Void) {
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }

    /// Runs `block` on the tap thread after `delay`. Returns the timer so it can be invalidated.
    @discardableResult
    func after(_ delay: TimeInterval, _ block: @escaping @Sendable () -> Void) -> CFRunLoopTimer? {
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + delay, 0, 0, 0) { _ in
            block()
        }
        CFRunLoopAddTimer(runLoop, timer, .defaultMode)
        return timer
    }
}
