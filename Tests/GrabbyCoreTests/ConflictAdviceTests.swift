import Testing
@testable import GrabbyCore

@Suite struct ConflictAdviceTests {
    @Test func betterMouseNamesToolAndButton() {
        let c = ConflictAdvice.make(tools: [.betterMouse], actionButton: 4)
        #expect(c.count == 1)
        #expect(c[0].tool == .betterMouse)
        #expect(c[0].advice.contains("BetterMouse"))
        #expect(c[0].advice.contains("button 4"))
    }

    @Test func gHubAndOptionsPlusGiveDefaultAssignmentInstruction() {
        let c = ConflictAdvice.make(tools: [.logitechGHub, .logitechOptionsPlus], actionButton: 3)
        #expect(c.map(\.tool) == [.logitechGHub, .logitechOptionsPlus])
        #expect(c[0].advice.contains("Logitech G HUB"))
        #expect(c[0].advice.contains("default"))
        #expect(c[1].advice.contains("Options+"))
        #expect(c[1].advice.contains("default"))
    }

    @Test func nilButtonAvoidsANumber() {
        let c = ConflictAdvice.make(tools: [.betterMouse], actionButton: nil)
        #expect(!c[0].advice.contains("button 4"))
        #expect(c[0].advice.contains("the button you choose"))
    }

    @Test func noToolsNoConflicts() {
        #expect(ConflictAdvice.make(tools: [], actionButton: 4).isEmpty)
    }
}
