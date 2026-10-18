import Foundation
import GrabbyCore
import GrabbyEngines

/// Observable state behind the Settings window. Every change is validated, saved, and pushed to the app.
@MainActor
final class SettingsModel: ObservableObject {
    enum LearnState: Equatable {
        case idle
        case listening
        case message(String)
    }

    @Published var settings: Settings {
        didSet { persist() }
    }
    @Published var status = "Starting..."
    @Published var learnState: LearnState = .idle
    @Published var conflicts: [Conflict] = []
    @Published var launchAtLoginError: String?

    private let store: SettingsStore
    private let onChange: (Settings) -> Void
    private let learner = LearnButtonController()
    var onLearnStart: (() -> Void)?
    var onLearnEnd: (() -> Void)?

    init(settings: Settings, store: SettingsStore, onChange: @escaping (Settings) -> Void) {
        self.settings = settings
        self.store = store
        self.onChange = onChange
        learner.onOutcome = { [weak self] outcome in self?.handle(outcome) }
    }

    var actionButtonLabel: String {
        settings.actionButton.map { "Button \($0)" } ?? "Not set"
    }

    func startLearning() {
        onLearnStart?()
        learnState = .listening
        learner.start()
    }

    func cancelLearning() {
        learner.stop()
        learnState = .idle
        onLearnEnd?()
    }

    private func handle(_ outcome: LearnButtonSession.Outcome) {
        switch outcome {
        case .learned(let n):
            settings.actionButton = n
            learnState = .message("Button \(n) is now the action button.")
            onLearnEnd?()
        case .rejected(let reason):
            learnState = .message(reason)
            if !learner.isListening { onLearnEnd?() }
        case .timedOut:
            learnState = .message("Nothing arrived in 10 seconds. Your mouse software (Logitech G HUB, BetterMouse) may have remapped this button; set it back to its default there and try again.")
            onLearnEnd?()
        case .waiting, .finished:
            break
        }
    }

    private func persist() {
        do {
            let valid = try settings.validated()
            try store.save(valid)
            onChange(valid)
        } catch {
            Log.settings.error("Could not save settings: \(String(describing: error))")
        }
    }
}
