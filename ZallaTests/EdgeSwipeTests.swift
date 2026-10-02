import XCTest
@testable import Zalla

final class EdgeSwipeTests: XCTestCase {
    func testProgressFollowsTheFingerInward() {
        XCTAssertEqual(EdgeSwipe.progress(translation: 0, side: .left), 0)
        XCTAssertEqual(EdgeSwipe.progress(translation: 45, side: .left), 0.5, accuracy: 0.001)
        XCTAssertEqual(EdgeSwipe.progress(translation: 400, side: .left), 1)
        XCTAssertEqual(EdgeSwipe.progress(translation: -45, side: .right), 0.5, accuracy: 0.001)
        XCTAssertEqual(EdgeSwipe.progress(translation: 45, side: .right), 0, "Moving back toward the edge is no progress")
        XCTAssertEqual(EdgeSwipe.progress(translation: -20, side: .left), 0)
    }

    func testLongSwipeCommits() {
        XCTAssertTrue(EdgeSwipe.shouldCommit(translation: 100, velocity: 0, side: .left))
        XCTAssertTrue(EdgeSwipe.shouldCommit(translation: -100, velocity: 0, side: .right))
        XCTAssertFalse(EdgeSwipe.shouldCommit(translation: 60, velocity: 0, side: .left))
        XCTAssertFalse(EdgeSwipe.shouldCommit(translation: 100, velocity: 0, side: .right))
    }

    func testQuickFlickCommitsButTinyOnesDoNot() {
        XCTAssertTrue(EdgeSwipe.shouldCommit(translation: 40, velocity: 900, side: .left))
        XCTAssertTrue(EdgeSwipe.shouldCommit(translation: -40, velocity: -900, side: .right))
        XCTAssertFalse(EdgeSwipe.shouldCommit(translation: 10, velocity: 2000, side: .left))
        XCTAssertFalse(EdgeSwipe.shouldCommit(translation: 40, velocity: -900, side: .left), "A flick back toward the edge cancels")
    }

    func testOnlyBeginsWhenThereIsSomewhereToGo() {
        XCTAssertTrue(EdgeSwipe.canBegin(side: .left, enabled: true, canGoBack: true, canGoForward: false))
        XCTAssertFalse(EdgeSwipe.canBegin(side: .left, enabled: true, canGoBack: false, canGoForward: true))
        XCTAssertTrue(EdgeSwipe.canBegin(side: .right, enabled: true, canGoBack: false, canGoForward: true))
        XCTAssertFalse(EdgeSwipe.canBegin(side: .right, enabled: true, canGoBack: true, canGoForward: false))
        XCTAssertFalse(EdgeSwipe.canBegin(side: .left, enabled: false, canGoBack: true, canGoForward: true))
    }

    func testSettingDefaultsToOn() {
        let defaults = UserDefaults(suiteName: "EdgeSwipeTests.default")!
        defaults.removePersistentDomain(forName: "EdgeSwipeTests.default")
        XCTAssertTrue(SwipeNavigation.enabled(in: defaults))
        defaults.set(false, forKey: SwipeNavigation.storageKey)
        XCTAssertFalse(SwipeNavigation.enabled(in: defaults))
    }
}
