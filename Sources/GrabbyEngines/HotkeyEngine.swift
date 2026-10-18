import CoreGraphics
import Foundation
import GrabbyCore
import GrabbyPrivate

/// Triggers Mission Control, App Expose, Show Desktop and Space moves through the system's
/// own symbolic hotkeys, whatever shortcut the user has bound, and restores any temporary rebind.
public final class HotkeyEngine: @unchecked Sendable {
    public struct Binding: Equatable, CustomStringConvertible {
        public var keyEquivalent: UInt16
        public var virtualKeyCode: CGKeyCode
        public var modifiers: UInt32
        public var enabled: Bool
        public var description: String {
            "keq=\(keyEquivalent) vkc=\(virtualKeyCode) mods=0x\(String(modifiers, radix: 16)) enabled=\(enabled)"
        }
    }

    private static let nullKeyEquivalent: UInt16 = 0xFFFF
    private static let nullVirtualKey: CGKeyCode = 0xFFFF
    private static let outOfReachBase: Int32 = 400

    private let api: grabby_private_api

    public init(api: grabby_private_api) {
        self.api = api
    }

    public static func hotKeyID(for step: StepCommand) -> Int32 {
        switch step {
        case .moveSpaceLeft: return GRABBY_SHK_SPACE_LEFT
        case .moveSpaceRight: return GRABBY_SHK_SPACE_RIGHT
        case .missionControl: return GRABBY_SHK_MISSION_CONTROL
        case .appExpose: return GRABBY_SHK_APP_EXPOSE
        case .showDesktop: return GRABBY_SHK_SHOW_DESKTOP
        case .screenshotSelection: return GRABBY_SHK_SCREENSHOT_REGION
        case .screenshotOptions: return GRABBY_SHK_SCREENSHOT_OPTIONS
        }
    }

    public func perform(_ step: StepCommand) {
        let id = HotkeyEngine.hotKeyID(for: step)
        Log.engine.debug("HotkeyEngine: step \(String(describing: step)) hotkey \(id)")
        trigger(hotKey: id)
    }

    public func binding(for hotKey: Int32) -> Binding? {
        guard let get = api.CGSGetSymbolicHotKeyValue, let isEnabled = api.CGSIsSymbolicHotKeyEnabled else { return nil }
        var keq: UInt16 = 0
        var vkc: CGKeyCode = 0
        var mods: UInt32 = 0
        guard get(hotKey, &keq, &vkc, &mods) == .success else { return nil }
        return Binding(keyEquivalent: keq, virtualKeyCode: vkc, modifiers: mods, enabled: isEnabled(hotKey))
    }

    private func trigger(hotKey: Int32) {
        guard let current = binding(for: hotKey), let setValue = api.CGSSetSymbolicHotKeyValue,
              let setEnabled = api.CGSSetSymbolicHotKeyEnabled else {
            Log.engine.error("HotkeyEngine: symbolic hotkey API unavailable, posting default shortcut")
            postDefaultShortcut(hotKey: hotKey)
            return
        }
        let usable = current.enabled && current.virtualKeyCode != HotkeyEngine.nullVirtualKey
        if usable {
            postKey(virtualKey: current.virtualKeyCode, modifiers: current.modifiers)
            return
        }
        // Temporarily bind the feature to a key no keyboard produces, press it, then restore.
        let tempKey = CGKeyCode(hotKey + HotkeyEngine.outOfReachBase)
        let tempMods = GRABBY_CGS_NUMERIC_PAD_MASK | GRABBY_CGS_FUNCTION_KEY_MASK
        _ = setEnabled(hotKey, true)
        let err = setValue(hotKey, HotkeyEngine.nullKeyEquivalent, tempKey, tempMods)
        if err != .success {
            Log.engine.error("HotkeyEngine: rebind failed (\(err.rawValue))")
        }
        defer {
            _ = setValue(hotKey, current.keyEquivalent, current.virtualKeyCode, current.modifiers)
            _ = setEnabled(hotKey, current.enabled)
            Log.engine.debug("HotkeyEngine: restored \(hotKey) to \(current.description)")
        }
        postKey(virtualKey: tempKey, modifiers: tempMods)
        usleep(30_000)
    }

    private func postKey(virtualKey: CGKeyCode, modifiers: UInt32) {
        let source = GrabbyEventSource.shared
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else { return }
        let flags = CGEventFlags(rawValue: UInt64(modifiers) & 0xFFFF_0000)
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Last resort when the symbolic hotkey API is missing: the stock shortcuts.
    private func postDefaultShortcut(hotKey: Int32) {
        let control = UInt32(CGEventFlags.maskControl.rawValue)
        switch hotKey {
        case GRABBY_SHK_SPACE_LEFT: postKey(virtualKey: 123, modifiers: control)
        case GRABBY_SHK_SPACE_RIGHT: postKey(virtualKey: 124, modifiers: control)
        case GRABBY_SHK_MISSION_CONTROL: postKey(virtualKey: 126, modifiers: control)
        case GRABBY_SHK_APP_EXPOSE: postKey(virtualKey: 125, modifiers: control)
        case GRABBY_SHK_SHOW_DESKTOP: postKey(virtualKey: 103, modifiers: 0)
        case GRABBY_SHK_SCREENSHOT_REGION:
            postKey(virtualKey: 21, modifiers: UInt32(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue))
        case GRABBY_SHK_SCREENSHOT_OPTIONS:
            postKey(virtualKey: 23, modifiers: UInt32(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue))
        default: break
        }
    }
}
