import Foundation

/// The "press the button you want" step. Pure; the app feeds it presses and clock ticks.
public struct LearnButtonSession: Sendable {
    public static let timeout: Duration = .seconds(10)

    public enum Outcome: Equatable, Sendable {
        case waiting
        case rejected(reason: String)
        case learned(Int)
        case timedOut
        case finished
    }

    private let startedAt: Duration
    private var finished = false

    public static func start(at now: Duration) -> LearnButtonSession {
        LearnButtonSession(startedAt: now)
    }

    private init(startedAt: Duration) {
        self.startedAt = startedAt
    }

    public mutating func buttonPressed(number: Int, at now: Duration) -> Outcome {
        if finished { return .finished }
        switch number {
        case 0: return .rejected(reason: "The left button can't be the action button. Press a side or extra button.")
        case 1: return .rejected(reason: "The right button can't be the action button. Press a side or extra button.")
        default:
            guard Settings.validButtons.contains(number) else {
                return .rejected(reason: "Button \(number) is out of range.")
            }
            finished = true
            return .learned(number)
        }
    }

    public mutating func tick(now: Duration) -> Outcome {
        if finished { return .finished }
        if now - startedAt >= LearnButtonSession.timeout {
            finished = true
            return .timedOut
        }
        return .waiting
    }
}
