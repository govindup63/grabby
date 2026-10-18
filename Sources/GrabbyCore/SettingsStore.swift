import Foundation

public struct SettingsStore: Sendable {
    private let read: @Sendable () throws -> Data?
    private let write: @Sendable (Data) throws -> Void

    public init(read: @escaping @Sendable () throws -> Data?,
                write: @escaping @Sendable (Data) throws -> Void) {
        self.read = read
        self.write = write
    }

    /// Defaults when the file is missing, unreadable, undecodable, or from an unknown schema.
    public func load() -> Settings {
        guard let data = try? read(), let decoded = try? JSONDecoder().decode(Settings.self, from: data),
              decoded.schemaVersion == Settings.currentSchemaVersion,
              let valid = try? decoded.validated() else {
            return Settings.defaults
        }
        return valid
    }

    public func save(_ settings: Settings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try write(encoder.encode(settings))
    }
}
