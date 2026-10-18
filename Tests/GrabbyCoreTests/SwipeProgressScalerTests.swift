import Testing
@testable import GrabbyCore

@Suite struct SwipeProgressScalerTests {
    let screen = Size(width: 1512, height: 982)

    @Test(arguments: [(2, 2.0), (3, 1.5), (5, 1.25)])
    func oneScreenWidthPlusSeparatorIsOneSpace(spaces: Int, expected: Double) {
        let s = SwipeProgressScaler(screen: screen, spaceCount: spaces, naturalDirection: false)
        let progress = s.horizontalProgress(forDelta: -(screen.width + SwipeProgressScaler.spaceSeparatorWidth))
        #expect(abs(progress - expected) < 1e-9)
    }

    @Test func singleSpaceUsesTwo() {
        let s = SwipeProgressScaler(screen: screen, spaceCount: 1, naturalDirection: false)
        let progress = s.horizontalProgress(forDelta: -(screen.width + 63))
        #expect(abs(progress - 2.0) < 1e-9)
    }

    @Test func naturalDirectionFlipsSign() {
        let s = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: true)
        let progress = s.horizontalProgress(forDelta: -(screen.width + 63))
        #expect(abs(progress + 2.0) < 1e-9)
    }

    @Test func verticalScreenHeightIsOne() {
        let s = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: false)
        #expect(abs(s.verticalProgress(forDelta: screen.height) - 1.0) < 1e-9)
        let n = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: true)
        #expect(abs(n.verticalProgress(forDelta: screen.height) + 1.0) < 1e-9)
    }
}
