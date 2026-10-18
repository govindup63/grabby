import Foundation

public enum SettingsError: Error, Equatable {
    case invalidButton
}

public struct Settings: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1
    public static let validButtons = 2...31

    public var schemaVersion: Int
    public var actionButton: Int?
    public var switchingStyle: SwitchingStyle
    public var dragDownAction: DragDownAction
    public var tapAction: TapAction
    public var naturalDirection: Bool?
    public var pinPointer: Bool
    public var launchAtLogin: Bool
    /// 0 = the desktop only follows the mouse; 1 = a quick flick carries it most of a desktop.
    public var throwStrength: Double

    public static let defaults = Settings(
        schemaVersion: currentSchemaVersion,
        actionButton: nil,
        switchingStyle: .smooth,
        dragDownAction: .exitMissionControl,
        tapAction: .none,
        naturalDirection: nil,
        pinPointer: false,
        launchAtLogin: false,
        throwStrength: 0.35
    )

    public init(schemaVersion: Int, actionButton: Int?, switchingStyle: SwitchingStyle,
                dragDownAction: DragDownAction, tapAction: TapAction, naturalDirection: Bool?,
                pinPointer: Bool, launchAtLogin: Bool, throwStrength: Double) {
        self.schemaVersion = schemaVersion
        self.actionButton = actionButton
        self.switchingStyle = switchingStyle
        self.dragDownAction = dragDownAction
        self.tapAction = tapAction
        self.naturalDirection = naturalDirection
        self.pinPointer = pinPointer
        self.launchAtLogin = launchAtLogin
        self.throwStrength = throwStrength
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.defaults
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? d.schemaVersion
        actionButton = try c.decodeIfPresent(Int.self, forKey: .actionButton) ?? d.actionButton
        switchingStyle = try c.decodeIfPresent(SwitchingStyle.self, forKey: .switchingStyle) ?? d.switchingStyle
        dragDownAction = try c.decodeIfPresent(DragDownAction.self, forKey: .dragDownAction) ?? d.dragDownAction
        tapAction = try c.decodeIfPresent(TapAction.self, forKey: .tapAction) ?? d.tapAction
        naturalDirection = try c.decodeIfPresent(Bool.self, forKey: .naturalDirection) ?? d.naturalDirection
        pinPointer = try c.decodeIfPresent(Bool.self, forKey: .pinPointer) ?? d.pinPointer
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        throwStrength = try c.decodeIfPresent(Double.self, forKey: .throwStrength) ?? d.throwStrength
    }

    public func validated() throws -> Settings {
        if let b = actionButton, !Settings.validButtons.contains(b) {
            throw SettingsError.invalidButton
        }
        var copy = self
        copy.throwStrength = min(1, max(0, throwStrength))
        return copy
    }
}
