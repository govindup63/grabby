import CoreGraphics
import Foundation
import GrabbyCore
import GrabbyEngines
import GrabbyPrivate

// grabby-probe: posts one synthetic Dock Swipe and reports whether the active Space changed.
// See specs/001-mouse-action-button/contracts/grabby-probe-cli.md.

enum Direction: String { case left, right }

struct Options {
    var symbols = false
    var direction = Direction.right
    var repeatCount = 1
    var json = false
    var hotkey: StepCommand?
}

func usage() -> Never {
    FileHandle.standardError.write(Data("""
    usage: grabby-probe [--direction left|right] [--repeat N] [--json]
           grabby-probe --symbols
           grabby-probe --hotkey left|right|mission-control|app-expose|show-desktop

    """.utf8))
    exit(64)
}

func parse(_ args: [String]) -> Options {
    var o = Options()
    var i = 0
    while i < args.count {
        switch args[i] {
        case "--symbols": o.symbols = true
        case "--json": o.json = true
        case "--direction":
            i += 1
            guard i < args.count, let d = Direction(rawValue: args[i]) else { usage() }
            o.direction = d
        case "--repeat":
            i += 1
            guard i < args.count, let n = Int(args[i]), n > 0 else { usage() }
            o.repeatCount = n
        case "--hotkey":
            i += 1
            guard i < args.count else { usage() }
            switch args[i] {
            case "left": o.hotkey = .moveSpaceLeft
            case "right": o.hotkey = .moveSpaceRight
            case "mission-control": o.hotkey = .missionControl
            case "app-expose": o.hotkey = .appExpose
            case "show-desktop": o.hotkey = .showDesktop
            default: usage()
            }
        default: usage()
        }
        i += 1
    }
    return o
}

let options = parse(Array(CommandLine.arguments.dropFirst()))
var api = grabby_private_resolve()

if options.symbols {
    var missing = 0
    for i in 0..<Int(GRABBY_PRIVATE_SYMBOL_COUNT) {
        let present = withUnsafePointer(to: &api) { grabby_private_symbol_present($0, Int32(i)) }
        print("\(String(cString: grabby_private_symbol_name(Int32(i)))): \(present ? "OK" : "MISSING")")
        if !present { missing += 1 }
    }
    exit(missing == 0 ? 0 : 2)
}

guard CGPreflightPostEventAccess() else {
    FileHandle.standardError.write(Data("grabby-probe: this terminal needs Accessibility access to post events\n".utf8))
    exit(2)
}
let allPresent = withUnsafePointer(to: &api) { grabby_private_all_present($0) }
guard allPresent else {
    FileHandle.standardError.write(Data("grabby-probe: private symbols missing, run --symbols\n".utf8))
    exit(2)
}

let spaces = SpaceObserver(api: api)
let hotkeys = HotkeyEngine(api: api)
let dock = DockSwipeEngine(api: api, fakeFailure: false)

func report(direction: String, before: UInt64, after: UInt64, elapsedMs: Int) {
    let changed = before != after
    if options.json {
        print(#"{"direction":"\#(direction)","before":\#(before),"after":\#(after),"changed":\#(changed),"elapsedMs":\#(elapsedMs)}"#)
    } else {
        print("space before=\(before) after=\(after) changed=\(changed ? "yes" : "no") elapsed=\(elapsedMs)ms")
    }
}

if let step = options.hotkey {
    let id = HotkeyEngine.hotKeyID(for: step)
    let before = spaces.activeSpace()
    let bindingBefore = hotkeys.binding(for: id)
    print("binding before: \(bindingBefore.map { $0.description } ?? "unavailable")")
    let start = Date()
    hotkeys.perform(step)
    usleep(600_000)
    let bindingAfter = hotkeys.binding(for: id)
    print("binding after:  \(bindingAfter.map { $0.description } ?? "unavailable")")
    report(direction: "\(step)", before: before, after: spaces.activeSpace(), elapsedMs: Int(Date().timeIntervalSince(start) * 1000))
    exit(bindingBefore == bindingAfter ? 0 : 1)
}

var failures = 0
var direction = options.direction
for _ in 0..<options.repeatCount {
    let sign: Double = direction == .right ? 1 : -1
    let before = spaces.activeSpace()
    let start = Date()
    let steps = 18
    var progress = 0.0
    dock.post(axis: .horizontal, phase: .began, progress: 0)
    for _ in 0..<steps {
        usleep(8_000)
        progress += sign * (1.0 / Double(steps))
        dock.post(axis: .horizontal, phase: .changed, progress: progress)
    }
    let lastDelta = sign * (1.0 / Double(steps))
    dock.post(axis: .horizontal, phase: .ended, progress: progress, exitSpeed: EndPhaseDecider.exitSpeed(lastDelta: lastDelta))
    usleep(400_000)
    let after = spaces.activeSpace()
    report(direction: direction.rawValue, before: before, after: after, elapsedMs: Int(Date().timeIntervalSince(start) * 1000))
    if before == after { failures += 1 }
    direction = direction == .right ? .left : .right
    usleep(700_000)
}
exit(failures == 0 ? 0 : 1)
