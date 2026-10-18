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

    public static let defaults = Settings(
        schemaVersion: currentSchemaVersion,
        actionButton: nil,
        switchingStyle: .smooth,
        dragDownAction: .appExpose,
        tapAction: .missionControl,
        naturalDirection: nil,
        pinPointer: false,
        launchAtLogin: false
    )

    public init(schemaVersion: Int, actionButton: Int?, switchingStyle: SwitchingStyle,
                dragDownAction: DragDownAction, tapAction: TapAction, naturalDirection: Bool?,
                pinPointer: Bool, launchAtLogin: Bool) {
        self.schemaVersion = schemaVersion
        self.actionButton = actionButton
        self.switchingStyle = switchingStyle
        self.dragDownAction = dragDownAction
        self.tapAction = tapAction
        self.naturalDirection = naturalDirection
        self.pinPointer = pinPointer
        self.launchAtLogin = launchAtLogin
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
    }

    public func validated() throws -> Settings {
        if let b = actionButton, !Settings.validButtons.contains(b) {
            throw SettingsError.invalidButton
        }
        return self
    }
}
