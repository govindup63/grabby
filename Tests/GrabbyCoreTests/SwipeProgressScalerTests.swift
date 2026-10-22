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

    @Test func upwardMotionIsPositiveLikeATrackpadFingerAndScreenHeightIsOne() {
        // Recorded on macOS 27: three fingers up (Mission Control) is positive progress.
        let s = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: false)
        #expect(abs(s.verticalProgress(forDelta: -screen.height) - 1.0) < 1e-9)
        #expect(s.verticalProgress(forDelta: 100) < 0)
        let n = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: true)
        #expect(abs(n.verticalProgress(forDelta: -screen.height) + 1.0) < 1e-9)
    }

    // macOS 26 and earlier read the gesture from undocumented CGEvent fields and use Mac Mouse Fix's
    // measured scale: one desktop is 1 + 1/(spaces - 1) progress (2.0 with a single Space).
    @Test(arguments: [(1, 2.0), (2, 2.0), (3, 1.5), (5, 1.25)])
    func legacyFormatUsesMacMouseFixScale(spaces: Int, expected: Double) {
        let s = SwipeProgressScaler(screen: screen, spaceCount: spaces, naturalDirection: false, format: .legacyFields)
        #expect(abs(s.offsetForOneSpace - expected) < 1e-9)
        let progress = s.horizontalProgress(forDelta: -(screen.width + SwipeProgressScaler.spaceSeparatorWidth))
        #expect(abs(progress - expected) < 1e-9)   // Mac Mouse Fix: progress = -dx * scale
    }

    @Test func legacyVerticalIsScreenHeightWithMacMouseFixSign() {
        let s = SwipeProgressScaler(screen: screen, spaceCount: 2, naturalDirection: false, format: .legacyFields)
        #expect(abs(s.verticalProgress(forDelta: screen.height) - 1.0) < 1e-9)
    }

    @Test func hidEventFormatIsTheDefault() {
        let a = SwipeProgressScaler(screen: screen, spaceCount: 3, naturalDirection: false)
        let b = SwipeProgressScaler(screen: screen, spaceCount: 3, naturalDirection: false, format: .hidEvent)
        #expect(a.offsetForOneSpace == b.offsetForOneSpace && a.offsetForOneSpace == 1.0)
    }
}
