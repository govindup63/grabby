import Foundation

public enum SettingsError: Error, Equatable {
    case invalidButton
}

public struct Settings: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1
    public static let validButtons = 2...31

    public var schemaVersion: Int
    public var actionButton: Int?
    public var tapAction: TapAction
    /// nil follows the system's natural scrolling setting; true or false overrides it.
    public var naturalDirection: Bool?
    /// 0 = where you let go decides; 1 = the speed of the hand at release counts fully.
    public var throwStrength: Double
    /// Draw a glowing line behind the pointer while the action button is held.
    public var showTrail: Bool
    public var launchAtLogin: Bool

    public static let defaults = Settings(
        schemaVersion: currentSchemaVersion,
        actionButton: nil,
        tapAction: .none,
        naturalDirection: nil,
        throwStrength: 0.35,
        showTrail: true,
        launchAtLogin: false
    )

    public init(schemaVersion: Int, actionButton: Int?, tapAction: TapAction, naturalDirection: Bool?,
                throwStrength: Double, showTrail: Bool, launchAtLogin: Bool) {
        self.schemaVersion = schemaVersion
        self.actionButton = actionButton
        self.tapAction = tapAction
        self.naturalDirection = naturalDirection
        self.throwStrength = throwStrength
        self.showTrail = showTrail
        self.launchAtLogin = launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.defaults
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? d.schemaVersion
        actionButton = try c.decodeIfPresent(Int.self, forKey: .actionButton) ?? d.actionButton
        tapAction = try c.decodeIfPresent(TapAction.self, forKey: .tapAction) ?? d.tapAction
        naturalDirection = try c.decodeIfPresent(Bool.self, forKey: .naturalDirection) ?? d.naturalDirection
        throwStrength = try c.decodeIfPresent(Double.self, forKey: .throwStrength) ?? d.throwStrength
        showTrail = try c.decodeIfPresent(Bool.self, forKey: .showTrail) ?? d.showTrail
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
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
