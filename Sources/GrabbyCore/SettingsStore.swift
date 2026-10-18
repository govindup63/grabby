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

    /// A store on disk. Creates the directory on save and moves an undecodable file aside as
    /// `settings.json.broken` on load so defaults take over without losing the old file.
    public static func fileBacked(url: URL) -> SettingsStore {
        SettingsStore(
            read: {
                guard let data = try? Data(contentsOf: url) else { return nil }
                if (try? JSONDecoder().decode(Settings.self, from: data)) == nil {
                    let broken = url.appendingPathExtension("broken")
                    try? FileManager.default.removeItem(at: broken)
                    try? FileManager.default.moveItem(at: url, to: broken)
                    return nil
                }
                return data
            },
            write: { data in
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            }
        )
    }
}
