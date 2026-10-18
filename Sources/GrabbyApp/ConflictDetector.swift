import AppKit
import GrabbyCore

/// Finds running mouse tools that would fight Grabby for the action button.
@MainActor
enum ConflictDetector {
    static func runningTools() -> [ConflictTool] {
        var found: [ConflictTool] = []
        for app in NSWorkspace.shared.runningApplications {
            let id = (app.bundleIdentifier ?? "").lowercased()
            let name = (app.localizedName ?? "").lowercased()
            let exe = (app.executableURL?.lastPathComponent ?? "").lowercased()
            if id.contains("bettermouse") || name.contains("bettermouse") {
                found.append(.betterMouse)
            } else if id.contains("optionsplus") || name.contains("options+") || exe.contains("optionsplus") {
                found.append(.logitechOptionsPlus)
            } else if id.contains("ghub") || id.contains("lghub") || name.contains("g hub") || exe.hasPrefix("lghub") {
                found.append(.logitechGHub)
            }
        }
        var seen = Set<ConflictTool>()
        return found.filter { seen.insert($0).inserted }
    }

    static func conflicts(actionButton: Int?) -> [Conflict] {
        ConflictAdvice.make(tools: runningTools(), actionButton: actionButton)
    }
}
