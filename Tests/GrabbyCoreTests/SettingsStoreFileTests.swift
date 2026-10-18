import Foundation
import Testing
@testable import GrabbyCore

@Suite struct SettingsStoreFileTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("grabby-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    @Test func createsDirectoryWritesAndReadsBack() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = SettingsStore.fileBacked(url: url)
        var s = Settings.defaults
        s.actionButton = 4
        try store.save(s)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(store.load() == s)
    }

    @Test func missingFileLoadsDefaults() {
        let url = tempURL()
        #expect(SettingsStore.fileBacked(url: url).load() == Settings.defaults)
    }

    @Test func undecodableFileIsRenamedToBroken() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: url)
        let store = SettingsStore.fileBacked(url: url)
        #expect(store.load() == Settings.defaults)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(FileManager.default.fileExists(atPath: url.appendingPathExtension("broken").path))
    }
}
