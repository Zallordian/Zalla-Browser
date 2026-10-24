import XCTest
@testable import Zalla

final class BarLayoutTests: XCTestCase {
    func testKeyAndDefault() {
        XCTAssertEqual(BarLayout.storageKey, "bottomBarLayout")
        XCTAssertEqual(BarLayout.defaultLayout, .safari)
    }

    func testMigrationSafeDefault() {
        XCTAssertEqual(BarLayout.stored(nil), .safari)
        XCTAssertEqual(BarLayout.stored(""), .safari)
        XCTAssertEqual(BarLayout.stored("something old"), .safari)
        XCTAssertEqual(BarLayout.stored(BarLayout.classic.rawValue), .classic)
        XCTAssertEqual(BarLayout.stored(BarLayout.safari.rawValue), .safari)
    }

    func testUnsetDefaultsReadAsSafari() {
        let defaults = UserDefaults(suiteName: "BarLayoutTests")!
        defaults.removePersistentDomain(forName: "BarLayoutTests")
        XCTAssertEqual(BarLayout.stored(defaults.string(forKey: BarLayout.storageKey)), .safari)
    }

    func testSafariBarOnlyAtTheBottomAndNeverForQuickAction() {
        XCTAssertTrue(BarLayout.usesSafariBar(layout: .safari, style: .classic, placement: .bottom))
        XCTAssertTrue(BarLayout.usesSafariBar(layout: .safari, style: .compact, placement: .bottom))
        XCTAssertFalse(BarLayout.usesSafariBar(layout: .safari, style: .quickAction, placement: .bottom))
        XCTAssertFalse(BarLayout.usesSafariBar(layout: .safari, style: .classic, placement: .top))
        XCTAssertFalse(BarLayout.usesSafariBar(layout: .classic, style: .compact, placement: .bottom))
    }

    func testEditorEditsTheListSafariStyleShows() {
        XCTAssertEqual(BarLayout.editTarget(layout: .safari, style: .classic, placement: .bottom), .compact)
        XCTAssertEqual(BarLayout.editTarget(layout: .classic, style: .classic, placement: .bottom), .classic)
        XCTAssertEqual(BarLayout.editTarget(layout: .safari, style: .quickAction, placement: .bottom), .quickActionBar)
        XCTAssertEqual(BarLayout.editTarget(layout: .safari, style: .classic, placement: .top), .classic)
    }

    func testDefaultButtonsMatchSafariOrder() {
        XCTAssertEqual(ToolbarLayout.defaultCompact, [.back, .forward, .address, .tabs, .menu])
        let layout = ToolbarLayout.default
        XCTAssertEqual(layout.compactLeading, [.back, .forward])
        XCTAssertEqual(layout.compactTrailing, [.tabs, .menu])
    }

    func testMetricsAreSlimAndEven() {
        XCTAssertEqual(SafariBarMetrics.height, 48)
        XCTAssertLessThan(SafariBarMetrics.collapsedHeight, SafariBarMetrics.height)
        XCTAssertLessThanOrEqual(SafariBarMetrics.buttonSize, SafariBarMetrics.height)
        XCTAssertLessThan(SafariBarMetrics.edgeMargin, 12)
        XCTAssertEqual(SafariBarMetrics.opacity(enabled: true), 1)
        XCTAssertLessThan(SafariBarMetrics.opacity(enabled: false), 0.5)
        XCTAssertGreaterThan(SafariBarMetrics.springDamping, 0.7)
        XCTAssertLessThan(SafariBarMetrics.springDamping, 1)
    }

    func testRowAndCopy() {
        XCTAssertTrue(SettingsRowID.coveredKeys.contains(BarLayout.storageKey))
        XCTAssertEqual(SettingsRowID.barLayout.group, .toolbarAndTabs)
        for text in [BarLayout.settingsFooter, BarLayout.safari.title, BarLayout.classic.title] {
            XCTAssertFalse(text.contains("\u{2014}"))
            XCTAssertFalse(text.contains("\u{2013}"))
        }
    }
}
