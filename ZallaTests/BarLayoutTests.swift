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

/// Build 43: Back and Forward leave the Safari style bar when there is nowhere to go.
final class SafariBarVisibilityTests: XCTestCase {
    private let defaults: [ToolbarItemKind] = [.back, .forward, .address, .tabs, .menu]

    func testFreshTabShowsNeitherBackNorForward() {
        XCTAssertEqual(SafariBarMetrics.visibleItems(defaults, canGoBack: false, canGoForward: false), [.address, .tabs, .menu])
    }

    func testOnlyBack() {
        XCTAssertEqual(SafariBarMetrics.visibleItems(defaults, canGoBack: true, canGoForward: false), [.back, .address, .tabs, .menu])
    }

    func testOnlyForward() {
        XCTAssertEqual(SafariBarMetrics.visibleItems(defaults, canGoBack: false, canGoForward: true), [.forward, .address, .tabs, .menu])
    }

    func testBoth() {
        XCTAssertEqual(SafariBarMetrics.visibleItems(defaults, canGoBack: true, canGoForward: true), defaults)
    }

    func testCustomButtonsAlwaysStayAndKeepOrder() {
        let custom: [ToolbarItemKind] = [.share, .back, .address, .forward, .burn, .menu]
        XCTAssertEqual(SafariBarMetrics.visibleItems(custom, canGoBack: false, canGoForward: false), [.share, .address, .burn, .menu])
    }

    func testSplitListsFromTheDefaultLayout() {
        let layout = ToolbarLayout.default
        XCTAssertEqual(SafariBarMetrics.visibleItems(layout.compactLeading, canGoBack: false, canGoForward: false), [])
        XCTAssertEqual(SafariBarMetrics.visibleItems(layout.compactTrailing, canGoBack: false, canGoForward: false), [.tabs, .menu])
    }

    func testHiddenScaleIsAShrinkNotAVanish() {
        XCTAssertGreaterThan(SafariBarMetrics.hiddenButtonScale, 0)
        XCTAssertLessThan(SafariBarMetrics.hiddenButtonScale, 1)
    }
}

final class LoadProgressTests: XCTestCase {
    func testSkipsTinySteps() {
        XCTAssertEqual(LoadProgress.published(current: 0.5, incoming: 0.51), 0.5)
        XCTAssertEqual(LoadProgress.published(current: 0.5, incoming: 0.55), 0.55)
    }

    func testStartAndFinishAlwaysLand() {
        XCTAssertEqual(LoadProgress.published(current: 0.99, incoming: 1.0), 1.0)
        XCTAssertEqual(LoadProgress.published(current: 0.7, incoming: 0), 0)
        XCTAssertEqual(LoadProgress.published(current: 0.7, incoming: 0.1), 0.1, "A new load starts over")
    }

    func testClamps() {
        XCTAssertEqual(LoadProgress.published(current: 0, incoming: 1.4), 1)
        XCTAssertEqual(LoadProgress.published(current: 0.3, incoming: -1), 0)
    }

    func testUpdatePublishesOnlyRealChanges() {
        let progress = LoadProgress()
        progress.update(0.3)
        XCTAssertEqual(progress.value, 0.3)
        progress.update(0.31)
        XCTAssertEqual(progress.value, 0.3)
        progress.update(1)
        XCTAssertEqual(progress.value, 1)
    }
}
