import XCTest
@testable import Zalla

final class HomeShortcutsTests: XCTestCase {
    func testFreshInstallHasNoDefaultShortcuts() {
        XCTAssertTrue(HomeShortcuts.defaults.isEmpty)
        let defaults = UserDefaults(suiteName: "zalla.homeShortcuts.fresh")!
        defaults.removePersistentDomain(forName: "zalla.homeShortcuts.fresh")
        XCTAssertTrue(HomeShortcuts.load(from: defaults).isEmpty)
    }

    func testCodableRoundTrip() throws {
        let original = [
            HomeShortcut(title: "Example", urlString: "https://example.com", symbolName: "globe"),
            HomeShortcut(title: "Test", urlString: "https://test.example", symbolName: "star")
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([HomeShortcut].self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSeededIfEmptyUsesDefaultsAndKeepsCustomLists() {
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
        XCTAssertTrue(HomeShortcuts.load(from: defaults).isEmpty)
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

final class HomeShortcutAddingTests: XCTestCase {
    func testNormalizedURLAddsHttpsAndRejectsJunk() {
        XCTAssertEqual(HomeShortcuts.normalizedURLString("example.com"), "https://example.com")
        XCTAssertEqual(HomeShortcuts.normalizedURLString("  http://example.com/a "), "http://example.com/a")
        XCTAssertNil(HomeShortcuts.normalizedURLString(""))
        XCTAssertNil(HomeShortcuts.normalizedURLString("two words"))
        XCTAssertNil(HomeShortcuts.normalizedURLString("javascript:alert(1)"))
        XCTAssertNil(HomeShortcuts.normalizedURLString("ftp://example.com"))
        XCTAssertEqual(HomeShortcuts.normalizedURLString("localhost:8080"), "https://localhost:8080")
    }

    func testDuplicatesIgnoreSchemeWwwCaseAndSlash() {
        let list = [HomeShortcut(title: "A", urlString: "https://www.Example.com/", symbolName: "globe")]
        XCTAssertTrue(HomeShortcuts.contains(list, urlString: "http://example.com"))
        XCTAssertFalse(HomeShortcuts.contains(list, urlString: "https://example.org"))
    }

    func testAddSkipsDuplicatesAndRespectsTheCap() {
        let defaults = UserDefaults(suiteName: "zalla.homeShortcuts.add")!
        defaults.removePersistentDomain(forName: "zalla.homeShortcuts.add")
        let first = HomeShortcut(title: "A", urlString: "https://a.example", symbolName: "globe")
        XCTAssertTrue(HomeShortcuts.add(first, in: defaults))
        XCTAssertFalse(HomeShortcuts.add(first, in: defaults))
        XCTAssertEqual(HomeShortcuts.load(from: defaults).count, 1)
    }

    func testMakeShortcutNeedsTitleAndAddress() {
        XCTAssertNil(HomeShortcuts.makeShortcut(title: "", urlString: "example.com"))
        XCTAssertNil(HomeShortcuts.makeShortcut(title: "X", urlString: "two words"))
        XCTAssertEqual(HomeShortcuts.makeShortcut(title: "X", urlString: "example.com")?.urlString, "https://example.com")
    }
}

final class PopularSitesTests: XCTestCase {
    func testListIsBigUniqueAndUsable() {
        XCTAssertGreaterThanOrEqual(PopularSites.all.count, 80)
        XCTAssertEqual(Set(PopularSites.all.map(\.domain)).count, PopularSites.all.count)
        for site in PopularSites.all {
            XCTAssertNotNil(HomeShortcuts.normalizedURLString(site.urlString), site.domain)
            XCTAssertFalse(site.name.isEmpty)
            XCTAssertFalse(site.name.contains("\u{2014}"))
        }
    }

    func testSearchMatchesNameAndDomain() {
        XCTAssertEqual(PopularSites.matching("").count, PopularSites.all.count)
        XCTAssertTrue(PopularSites.matching("wiki").contains { $0.domain.contains("wikipedia") })
        XCTAssertTrue(PopularSites.matching("zzzzqqq").isEmpty)
    }

    func testHostLookupIgnoresWww() {
        let first = PopularSites.all[0]
        XCTAssertEqual(PopularSites.site(forHost: "www." + first.domain)?.domain, first.domain)
        XCTAssertNil(PopularSites.site(forHost: nil))
    }

    func testSymbolLabelsAreReadable() {
        XCTAssertEqual(HomeShortcuts.symbolLabel("magnifyingglass"), "Search")
        XCTAssertEqual(HomeShortcuts.symbolLabel("square.and.arrow.up"), "square and arrow up")
        for name in HomeShortcuts.curatedSymbols {
            XCTAssertFalse(HomeShortcuts.symbolLabel(name).contains("."), name)
        }
    }
}
