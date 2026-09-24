import XCTest
@testable import Zalla

final class HomeShortcutsTests: XCTestCase {
    func testDefaultsAreNonEmpty() {
        XCTAssertGreaterThanOrEqual(HomeShortcuts.defaults.count, 4)
        XCTAssertLessThanOrEqual(HomeShortcuts.defaults.count, 8)
        for shortcut in HomeShortcuts.defaults {
            XCTAssertFalse(shortcut.title.isEmpty)
            XCTAssertNotNil(shortcut.url)
            XCTAssertFalse(shortcut.symbolName.isEmpty)
        }
    }

    func testCodableRoundTrip() throws {
        let original = HomeShortcuts.defaults
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([HomeShortcut].self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSeededIfEmptyUsesDefaults() {
        XCTAssertEqual(HomeShortcuts.seededIfEmpty(nil), HomeShortcuts.defaults)
        XCTAssertEqual(HomeShortcuts.seededIfEmpty([]), HomeShortcuts.defaults)
        let custom = [HomeShortcut(title: "A", urlString: "https://a.test", symbolName: "globe")]
        XCTAssertEqual(HomeShortcuts.seededIfEmpty(custom), custom)
    }

    func testUserDefaultsRoundTrip() {
        let defaults = UserDefaults(suiteName: "zalla.homeShortcuts.tests")!
        defaults.removePersistentDomain(forName: "zalla.homeShortcuts.tests")
        let sample = [
            HomeShortcut(title: "Test", urlString: "https://example.com", symbolName: "star")
        ]
        HomeShortcuts.save(sample, to: defaults)
        let loaded = HomeShortcuts.load(from: defaults)
        XCTAssertEqual(loaded, sample)
        HomeShortcuts.resetToDefaults(in: defaults)
        XCTAssertEqual(HomeShortcuts.load(from: defaults), HomeShortcuts.defaults)
        XCTAssertTrue(defaults.bool(forKey: HomeShortcuts.showLogoKey))
        XCTAssertTrue(defaults.bool(forKey: HomeShortcuts.showSliderKey))
        XCTAssertTrue(defaults.bool(forKey: HomeShortcuts.showRecentHistoryKey))
    }

    func testEmptyListPersists() {
        let defaults = UserDefaults(suiteName: "zalla.homeShortcuts.empty")!
        defaults.removePersistentDomain(forName: "zalla.homeShortcuts.empty")
        HomeShortcuts.save([], to: defaults)
        XCTAssertEqual(HomeShortcuts.load(from: defaults), [])
    }

    func testHomeKeys() {
        XCTAssertEqual(HomeShortcuts.showRecentHistoryKey, "homeShowRecentHistory")
        XCTAssertEqual(HomeShortcuts.showSliderKey, "homeShowSlider")
    }

    func testSliderPages() {
        XCTAssertEqual(
            HomeWidgets.pages(sliderEnabled: false, showRecentHistory: true, isPrivate: false, hasHistory: true),
            [.welcome]
        )
        XCTAssertEqual(
            HomeWidgets.pages(sliderEnabled: true, showRecentHistory: true, isPrivate: false, hasHistory: true),
            [.welcome, .tabs, .recent]
        )
        XCTAssertEqual(
            HomeWidgets.pages(sliderEnabled: true, showRecentHistory: false, isPrivate: false, hasHistory: true),
            [.welcome, .tabs]
        )
        XCTAssertEqual(
            HomeWidgets.pages(sliderEnabled: true, showRecentHistory: true, isPrivate: true, hasHistory: true),
            [.welcome, .tabs],
            "Private tabs never surface history"
        )
        XCTAssertEqual(
            HomeWidgets.pages(sliderEnabled: true, showRecentHistory: true, isPrivate: false, hasHistory: false),
            [.welcome, .tabs]
        )
    }

    func testRecentPagesDedupesAndLimits() {
        let a = URL(string: "https://a.test")!
        let b = URL(string: "https://b.test")!
        let c = URL(string: "https://c.test")!
        let d = URL(string: "https://d.test")!
        let history = [
            SavedPage(title: "A", url: a),
            SavedPage(title: "A again", url: a),
            SavedPage(title: "B", url: b),
            SavedPage(title: "C", url: c),
            SavedPage(title: "D", url: d)
        ]
        let recent = HomeWidgets.recentPages(history)
        XCTAssertEqual(recent.map(\.url), [a, b, c])
        XCTAssertEqual(HomeWidgets.recentPages(history, limit: 10).count, 4)
        XCTAssertTrue(HomeWidgets.recentPages([]).isEmpty)
    }

    func testWidgetLabels() {
        XCTAssertEqual(HomeWidgets.tabCountLabel(1), "1 tab open")
        XCTAssertEqual(HomeWidgets.tabCountLabel(3), "3 tabs open")
        XCTAssertNil(HomeWidgets.privateTabLabel(0))
        XCTAssertEqual(HomeWidgets.privateTabLabel(2), "2 private")
        let untitled = SavedPage(title: "  ", url: URL(string: "https://www.example.com/x")!)
        XCTAssertEqual(HomeWidgets.displayTitle(for: untitled), "example.com")
    }
}
