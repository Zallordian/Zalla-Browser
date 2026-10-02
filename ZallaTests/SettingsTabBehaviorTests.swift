import XCTest
@testable import Zalla

final class SettingsTabBehaviorTests: XCTestCase {
    func testHapticsDefaultOn() {
        XCTAssertEqual(SettingsTabHaptics.storageKey, "settingsTabHaptics")
        XCTAssertTrue(SettingsTabHaptics.isEnabled(nil))
        XCTAssertTrue(SettingsTabHaptics.isEnabled(true))
        XCTAssertFalse(SettingsTabHaptics.isEnabled(false))
    }

    func testNoFadesWhenEverythingFits() {
        XCTAssertFalse(StripEdgeFade.canScroll(contentWidth: 300, viewportWidth: 390))
        XCTAssertEqual(StripEdgeFade.leadingOpacity(offset: 0, contentWidth: 300, viewportWidth: 390), 0)
        XCTAssertEqual(StripEdgeFade.trailingOpacity(offset: 0, contentWidth: 300, viewportWidth: 390), 0)
        XCTAssertEqual(StripEdgeFade.trailingOpacity(offset: 0, contentWidth: 300, viewportWidth: 0), 0)
    }

    func testFadesAtTheStartOfAScrollingStrip() {
        XCTAssertTrue(StripEdgeFade.canScroll(contentWidth: 520, viewportWidth: 390))
        XCTAssertEqual(StripEdgeFade.leadingOpacity(offset: 0, contentWidth: 520, viewportWidth: 390), 0)
        XCTAssertEqual(StripEdgeFade.trailingOpacity(offset: 0, contentWidth: 520, viewportWidth: 390), 1)
    }

    func testFadesInTheMiddleAndAtTheEnd() {
        XCTAssertEqual(StripEdgeFade.leadingOpacity(offset: 12, contentWidth: 520, viewportWidth: 390), 0.5, accuracy: 0.001)
        XCTAssertEqual(StripEdgeFade.leadingOpacity(offset: 60, contentWidth: 520, viewportWidth: 390), 1)
        XCTAssertEqual(StripEdgeFade.trailingOpacity(offset: 130, contentWidth: 520, viewportWidth: 390), 0)
        XCTAssertEqual(StripEdgeFade.trailingOpacity(offset: 118, contentWidth: 520, viewportWidth: 390), 0.5, accuracy: 0.001)
    }

    func testOverscrollIsClamped() {
        XCTAssertEqual(StripEdgeFade.leadingOpacity(offset: -40, contentWidth: 520, viewportWidth: 390), 0)
        XCTAssertEqual(StripEdgeFade.trailingOpacity(offset: 200, contentWidth: 520, viewportWidth: 390), 0)
    }
}
