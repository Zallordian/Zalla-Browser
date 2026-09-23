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
    }

    func testEmptyListPersists() {
        let defaults = UserDefaults(suiteName: "zalla.homeShortcuts.empty")!
        defaults.removePersistentDomain(forName: "zalla.homeShortcuts.empty")
        HomeShortcuts.save([], to: defaults)
        XCTAssertEqual(HomeShortcuts.load(from: defaults), [])
    }
}
