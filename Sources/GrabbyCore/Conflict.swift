import Foundation

public enum ConflictTool: Sendable, Equatable, Hashable {
    case betterMouse
    case logitechGHub
    case logitechOptionsPlus
}

public struct Conflict: Sendable, Equatable {
    public var tool: ConflictTool
    public var advice: String

    public init(tool: ConflictTool, advice: String) {
        self.tool = tool
        self.advice = advice
    }
}

public enum ConflictAdvice {
    public static func make(tools: [ConflictTool], actionButton: Int?) -> [Conflict] {
        let which = actionButton.map { "button \($0)" } ?? "the button you choose"
        return tools.map { tool in
            switch tool {
            case .betterMouse:
                return Conflict(tool: tool, advice: "BetterMouse is running. Quit it, or make sure \(which) has no assignment there, or the two will fight over it.")
            case .logitechGHub:
                return Conflict(tool: tool, advice: "Logitech G HUB is running. In G HUB, set \(which) to its default assignment so the click reaches Grabby.")
            case .logitechOptionsPlus:
                return Conflict(tool: tool, advice: "Logi Options+ is running. In Options+, set \(which) to its default assignment so the click reaches Grabby.")
            }
        }
    }
}
