import Foundation
import Testing
@testable import GrabbyCore

@Suite struct SettingsTests {
    @Test func defaultsMatchDataModel() {
        let s = Settings.defaults
        #expect(s.schemaVersion == 1)
        #expect(s.actionButton == nil)
        #expect(s.tapAction == .none)
        #expect(s.naturalDirection == nil)
        #expect(s.launchAtLogin == false)
        #expect(s.throwStrength == 0.35)
        #expect(s.showTrail == true)
    }

    @Test func validatedClampsThrowStrength() throws {
        var s = Settings.defaults
        s.throwStrength = 1.7
        #expect(try s.validated().throwStrength == 1.0)
        s.throwStrength = -0.2
        #expect(try s.validated().throwStrength == 0.0)
    }

    @Test func jsonRoundTrip() throws {
        var s = Settings.defaults
        s.actionButton = 4
        s.tapAction = .passThrough
        s.naturalDirection = false
        s.throwStrength = 0.8
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Settings.self, from: data)
        #expect(back == s)
    }

    @Test(arguments: [0, 1, 32]) func validatedRejectsBadButtons(button: Int) {
        var s = Settings.defaults
        s.actionButton = button
        #expect(throws: SettingsError.invalidButton) { try s.validated() }
    }

    @Test(arguments: [2, 31]) func validatedAcceptsEdgeButtons(button: Int) throws {
        var s = Settings.defaults
        s.actionButton = button
        #expect(try s.validated().actionButton == button)
    }

    @Test func validatedAcceptsNilButton() throws {
        #expect(try Settings.defaults.validated().actionButton == nil)
    }

    @Test func decodingIgnoresUnknownKeys() throws {
        let json = #"{"schemaVersion":1,"actionButton":3,"someFutureKey":true}"#
        let s = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(s.actionButton == 3)
    }

    @Test func decodingFillsMissingKeysWithDefaults() throws {
        let json = #"{"schemaVersion":1,"tapAction":"appExpose"}"#
        let s = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(s.tapAction == .appExpose)
        #expect(s.throwStrength == 0.35)
        #expect(s.naturalDirection == nil)
        #expect(s.showTrail == true)
    }

    @Test func storeReturnsDefaultsWhenFileMissing() {
        let store = SettingsStore(read: { nil }, write: { _ in })
        #expect(store.load() == Settings.defaults)
    }

    @Test func storeReturnsDefaultsWhenFileIsGarbage() {
        let store = SettingsStore(read: { Data("not json".utf8) }, write: { _ in })
        #expect(store.load() == Settings.defaults)
    }

    @Test func storeSavesWhatLoadReadsBack() throws {
        final class Box: @unchecked Sendable { var data: Data? }
        let box = Box()
        let store = SettingsStore(read: { box.data }, write: { box.data = $0 })
        var s = Settings.defaults
        s.actionButton = 5
        s.naturalDirection = true
        try store.save(s)
        #expect(store.load() == s)
    }
}
