import Testing
@testable import GrabbyCore

@Suite struct SwipeProgressScalerTests {
    let screen = Size(width: 1512, height: 982)

    @Test(arguments: [1, 2, 3, 5])
    func oneScreenWidthPlusSeparatorIsOneSpaceWhateverTheSpaceCount(spaces: Int) {
        let s = SwipeProgressScaler(screen: screen, spaceCount: spaces, naturalDirection: false)
        let progress = s.horizontalProgress(forDelta: screen.width + SwipeProgressScaler.spaceSeparatorWidth)
        #expect(abs(progress - 1.0) < 1e-9)
        #expect(s.offsetForOneSpace == 1.0)
    }

    @Test func leftwardMotionIsNegativeLikeATrackpadFinger() {
        let s = SwipeProgressScaler(screen: screen, spaceCount: 3, naturalDirection: false)
        #expect(s.horizontalProgress(forDelta: -100) < 0)
        #expect(s.horizontalProgress(forDelta: 100) > 0)
    }

    @Test func naturalDirectionOverrideFlipsSign() {
        let s = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: true)
        #expect(abs(s.horizontalProgress(forDelta: screen.width + 63) + 1.0) < 1e-9)
    }

    @Test func verticalScreenHeightIsOne() {
        let s = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: false)
        #expect(abs(s.verticalProgress(forDelta: screen.height) - 1.0) < 1e-9)
        let n = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: true)
        #expect(abs(n.verticalProgress(forDelta: screen.height) + 1.0) < 1e-9)
    }
}
