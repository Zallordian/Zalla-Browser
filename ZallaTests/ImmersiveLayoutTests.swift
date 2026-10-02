import XCTest
@testable import Zalla

final class ImmersiveLayoutTests: XCTestCase {
    func testDefaultIsOnAndKeyIsStable() {
        XCTAssertEqual(ImmersiveLayout.storageKey, "immersiveLayout")
        XCTAssertTrue(ImmersiveLayout.defaultEnabled)
        XCTAssertTrue(ImmersiveLayout.isEnabled(nil))
        XCTAssertTrue(ImmersiveLayout.isEnabled(true))
        XCTAssertFalse(ImmersiveLayout.isEnabled(false))
    }

    func testReadsFromDefaults() {
        let suite = "ImmersiveLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(ImmersiveLayout.isEnabled(in: defaults))
        defaults.set(false, forKey: ImmersiveLayout.storageKey)
        XCTAssertFalse(ImmersiveLayout.isEnabled(in: defaults))
        defaults.set(true, forKey: ImmersiveLayout.storageKey)
        XCTAssertTrue(ImmersiveLayout.isEnabled(in: defaults))
    }

    func testSolidLayoutKeepsTheMeasuredHeight() {
        XCTAssertEqual(ImmersiveLayout.bottomContentInset(barHeight: 90, homeIndicatorInset: 34, immersive: false), 90)
        XCTAssertEqual(ImmersiveLayout.bottomContentInset(barHeight: -5, homeIndicatorInset: 34, immersive: false), 0)
    }

    func testImmersiveInsetDropsTheHomeIndicatorSlack() {
        XCTAssertEqual(ImmersiveLayout.bottomContentInset(barHeight: 80, homeIndicatorInset: 34, immersive: true), 46)
        XCTAssertEqual(ImmersiveLayout.bottomContentInset(barHeight: 80, homeIndicatorInset: 0, immersive: true), 80)
        XCTAssertEqual(ImmersiveLayout.bottomContentInset(barHeight: 20, homeIndicatorInset: 34, immersive: true), 0)
        XCTAssertEqual(ImmersiveLayout.bottomContentInset(barHeight: 0, homeIndicatorInset: 34, immersive: true), 0)
        XCTAssertEqual(ImmersiveLayout.bottomContentInset(barHeight: 80, homeIndicatorInset: -3, immersive: true), 80)
    }

    func testKeyboardSizedInsetsAreIgnored() {
        XCTAssertEqual(ImmersiveLayout.homeIndicatorInset(fromSafeAreaBottom: 34), 34)
        XCTAssertEqual(ImmersiveLayout.homeIndicatorInset(fromSafeAreaBottom: 0), 0)
        XCTAssertNil(ImmersiveLayout.homeIndicatorInset(fromSafeAreaBottom: 336))
        XCTAssertNil(ImmersiveLayout.homeIndicatorInset(fromSafeAreaBottom: -1))
    }

    func testSpacingStaysSlim() {
        XCTAssertLessThanOrEqual(ImmersiveLayout.bottomGap, 20)
        XCTAssertGreaterThanOrEqual(ImmersiveLayout.bottomGap, 8)
        XCTAssertGreaterThan(ImmersiveLayout.solidBottomPullDown, 0)
        XCTAssertLessThan(ImmersiveLayout.solidBottomPullDown, 20)
    }
}
