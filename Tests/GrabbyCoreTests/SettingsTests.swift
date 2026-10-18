import Foundation
import Testing
@testable import GrabbyCore

@Suite struct SettingsTests {
    @Test func defaultsMatchDataModel() {
        let s = Settings.defaults
        #expect(s.schemaVersion == 1)
        #expect(s.actionButton == nil)
        #expect(s.switchingStyle == .smooth)
        #expect(s.dragDownAction == .appExpose)
        #expect(s.tapAction == .missionControl)
        #expect(s.naturalDirection == nil)
        #expect(s.pinPointer == false)
        #expect(s.launchAtLogin == false)
    }

    @Test func jsonRoundTrip() throws {
        var s = Settings.defaults
        s.actionButton = 4
        s.switchingStyle = .keyboard
        s.tapAction = .passThrough
        s.naturalDirection = false
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
        let json = #"{"schemaVersion":1,"tapAction":"none"}"#
        let s = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(s.tapAction == .none)
        #expect(s.dragDownAction == .appExpose)
        #expect(s.pinPointer == false)
        #expect(s.switchingStyle == .smooth)
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
        s.pinPointer = true
        try store.save(s)
        #expect(store.load() == s)
    }
}
