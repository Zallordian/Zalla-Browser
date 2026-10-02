import XCTest
@testable import Zalla

final class PullToRefreshTests: XCTestCase {
    func testDefaultsToOn() {
        let defaults = UserDefaults(suiteName: "PullToRefreshTests.default")!
        defaults.removePersistentDomain(forName: "PullToRefreshTests.default")
        XCTAssertTrue(PullToRefresh.enabled(in: defaults))
        defaults.set(false, forKey: PullToRefresh.storageKey)
        XCTAssertFalse(PullToRefresh.enabled(in: defaults))
        defaults.set(true, forKey: PullToRefresh.storageKey)
        XCTAssertTrue(PullToRefresh.enabled(in: defaults))
    }

    func testReloadsOnlyWhenOnWithAPageAndNoKeyboard() {
        XCTAssertTrue(PullToRefresh.shouldReload(enabled: true, keyboardVisible: false, hasPage: true))
        XCTAssertFalse(PullToRefresh.shouldReload(enabled: false, keyboardVisible: false, hasPage: true))
        XCTAssertFalse(PullToRefresh.shouldReload(enabled: true, keyboardVisible: true, hasPage: true), "A pull with the keyboard up just dismisses it")
        XCTAssertFalse(PullToRefresh.shouldReload(enabled: true, keyboardVisible: false, hasPage: false))
    }

    func testSpinnerTimeoutIsShort() {
        XCTAssertLessThanOrEqual(PullToRefresh.giveUpAfter, 15)
        XCTAssertGreaterThan(PullToRefresh.giveUpAfter, 0)
    }
}
