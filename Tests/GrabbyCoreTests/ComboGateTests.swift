import Testing
@testable import GrabbyCore

@Suite struct ComboGateTests {
    @Test func closedGateConsumesNothing() {
        let g = ComboGate()
        #expect(g.tryConsume() == false)
    }

    @Test func openGateConsumesExactlyOnce() {
        let g = ComboGate()
        g.open()
        #expect(g.tryConsume())
        #expect(g.tryConsume() == false)
    }

    @Test func closingResetsAndReopeningArmsAgain() {
        let g = ComboGate()
        g.open()
        g.close()
        #expect(g.tryConsume() == false)
        g.open()
        #expect(g.tryConsume())
    }
}
