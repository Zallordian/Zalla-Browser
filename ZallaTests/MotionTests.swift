import XCTest
@testable import Zalla

final class MotionTests: XCTestCase {
    func testEveryKindHasATimingWhenMotionIsAllowed() {
        for kind in MotionKind.allCases {
            let spec = MotionSpec.spec(for: kind, reduceMotion: false)
            XCTAssertNotNil(spec, "\(kind)")
            XCTAssertGreaterThan(spec?.time ?? 0, 0)
            XCTAssertGreaterThan(spec?.damping ?? 0, 0)
            XCTAssertLessThanOrEqual(spec?.damping ?? 2, 1)
        }
    }

    func testReduceMotionTurnsEverythingOffExceptAShortFade() {
        for kind in MotionKind.allCases where kind != .fade {
            XCTAssertNil(MotionSpec.spec(for: kind, reduceMotion: true), "\(kind)")
        }
        let reduced = MotionSpec.spec(for: .fade, reduceMotion: true)
        let normal = MotionSpec.spec(for: .fade, reduceMotion: false)
        XCTAssertEqual(reduced?.style, .easeOut)
        XCTAssertLessThan(reduced?.time ?? 1, normal?.time ?? 0)
    }

    func testSpringsAreQuickAndSettleWithoutMuchBounce() {
        for kind in [MotionKind.bar, .sheet, .card, .indicator] {
            let spec = MotionSpec.spec(for: kind, reduceMotion: false)
            XCTAssertEqual(spec?.style, .spring)
            XCTAssertLessThanOrEqual(spec?.time ?? 9, 0.5)
            XCTAssertGreaterThanOrEqual(spec?.damping ?? 0, 0.78)
        }
        // The pop is the one lively timing.
        let pop = MotionSpec.spec(for: .pop, reduceMotion: false)
        XCTAssertLessThan(pop?.damping ?? 1, 0.78)
    }

    func testBarKeepsTheAddressBarTimingFromEarlierBuilds() {
        XCTAssertEqual(MotionSpec.spec(for: .bar, reduceMotion: false), MotionSpec(style: .spring, time: 0.35, damping: 0.85))
    }

    func testPageFadeStartsJustUnderFullOpacity() {
        XCTAssertGreaterThan(MotionSpec.pageStartAlpha, 0.8)
        XCTAssertLessThan(MotionSpec.pageStartAlpha, 1)
        XCTAssertEqual(MotionSpec.spec(for: .page, reduceMotion: false)?.style, .easeOut)
    }

    func testCardFollowsTheFingerLeftAndResistsRight() {
        XCTAssertEqual(CardSwipe.followOffset(translation: -50), -50)
        XCTAssertEqual(CardSwipe.followOffset(translation: 0), 0)
        XCTAssertEqual(CardSwipe.followOffset(translation: 100), 20, accuracy: 0.0001)
    }

    func testCardFadeProgressIsClamped() {
        XCTAssertEqual(CardSwipe.progress(translation: 0), 0)
        XCTAssertEqual(CardSwipe.progress(translation: -40), 0.5, accuracy: 0.0001)
        XCTAssertEqual(CardSwipe.progress(translation: -400), 1)
        XCTAssertEqual(CardSwipe.progress(translation: 60), 0)
    }

    func testSwipeClosesOnDistanceOrOnAQuickFlick() {
        // Far enough left or up closes, as in earlier builds.
        XCTAssertTrue(CardSwipe.shouldClose(translationX: -81, translationY: 0, predictedX: -81))
        XCTAssertTrue(CardSwipe.shouldClose(translationX: 0, translationY: -81, predictedX: 0))
        // A short drag that stops does not.
        XCTAssertFalse(CardSwipe.shouldClose(translationX: -40, translationY: 0, predictedX: -60))
        // A short drag with a fast flick does.
        XCTAssertTrue(CardSwipe.shouldClose(translationX: -40, translationY: 0, predictedX: -260))
        // A flick to the right never closes, and a tiny twitch is not a flick.
        XCTAssertFalse(CardSwipe.shouldClose(translationX: 40, translationY: 0, predictedX: 300))
        XCTAssertFalse(CardSwipe.shouldClose(translationX: -10, translationY: 0, predictedX: -300))
    }
}
