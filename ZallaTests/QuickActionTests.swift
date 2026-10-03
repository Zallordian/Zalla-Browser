import XCTest
@testable import Zalla

final class QuickActionTests: XCTestCase {
    func testShortcutTypesMatchTheInfoPlistList() {
        XCTAssertEqual(QuickAction.allCases.map(\.shortcutType), [
            "com.zalla.browser.quickaction.newTab",
            "com.zalla.browser.quickaction.newPrivateTab",
            "com.zalla.browser.quickaction.search",
            "com.zalla.browser.quickaction.bookmarks",
            "com.zalla.browser.quickaction.burn"
        ])
        XCTAssertEqual(QuickAction.allCases.map(\.title), ["New Tab", "New Private Tab", "Search", "Bookmarks", "Burn It All"])
    }

    func testShortcutResolvesOnlyForZallaTypesWhileEnabled() {
        for action in QuickAction.allCases {
            XCTAssertEqual(QuickAction.resolve(shortcutType: action.shortcutType, enabled: true), action)
            XCTAssertNil(QuickAction.resolve(shortcutType: action.shortcutType, enabled: false))
        }
        XCTAssertNil(QuickAction.resolve(shortcutType: "com.zalla.browser.quickaction.nope", enabled: true))
        XCTAssertNil(QuickAction.resolve(shortcutType: "com.other.app.newTab", enabled: true))
        XCTAssertNil(QuickAction.resolve(shortcutType: "", enabled: true))
    }

    func testEveryActionRoutesToOneStepAndBurnOnlyAsks() {
        XCTAssertEqual(QuickAction.newTab.step, .newTab)
        XCTAssertEqual(QuickAction.newPrivateTab.step, .newPrivateTab)
        XCTAssertEqual(QuickAction.search.step, .focusAddressBar)
        XCTAssertEqual(QuickAction.bookmarks.step, .openLibrary)
        // Burn never burns by itself: its only step is the confirmation.
        XCTAssertEqual(QuickAction.burn.step, .confirmBurn)
    }

    func testLinksRoundTripAndLeaveWebAddressesAlone() {
        for action in QuickAction.allCases {
            XCTAssertEqual(action.link.flatMap { QuickAction.resolve(url: $0) }, action)
        }
        XCTAssertEqual(QuickAction.resolve(url: URL(string: "ZALLA://Search")!), .search)
        XCTAssertNil(QuickAction.resolve(url: URL(string: "zalla://open?url=https://example.com")!))
        XCTAssertNil(QuickAction.resolve(url: URL(string: "https://example.com/search")!))
        XCTAssertNil(QuickAction.resolve(url: URL(string: "other://burn")!))
        // A web link still opens as a web link.
        XCTAssertEqual(IncomingLink.webURL(from: URL(string: "https://example.com/a")!)?.absoluteString, "https://example.com/a")
    }

    func testNewTabReusesOnlyABlankRegularTab() {
        XCTAssertTrue(QuickAction.reusesCurrentTab(hasSelected: true, hasPage: false, isPrivate: false))
        XCTAssertFalse(QuickAction.reusesCurrentTab(hasSelected: true, hasPage: true, isPrivate: false))
        XCTAssertFalse(QuickAction.reusesCurrentTab(hasSelected: true, hasPage: false, isPrivate: true))
        XCTAssertFalse(QuickAction.reusesCurrentTab(hasSelected: false, hasPage: false, isPrivate: false))
    }

    func testSettingDefaultsOn() {
        let defaults = UserDefaults(suiteName: "QuickActionTests")!
        defaults.removePersistentDomain(forName: "QuickActionTests")
        XCTAssertTrue(QuickAction.isEnabled(in: defaults))
        defaults.set(false, forKey: QuickAction.storageKey)
        XCTAssertFalse(QuickAction.isEnabled(in: defaults))
    }

    func testDefaultBrowserCopyIsPlainAndHasNoDashes() {
        for text in [DefaultBrowser.settingsFooter, DefaultBrowser.quickActionsFooter] {
            XCTAssertFalse(text.contains("\u{2014}"))
            XCTAssertFalse(text.contains("\u{2013}"))
        }
        XCTAssertTrue(DefaultBrowser.settingsFooter.contains("Apple"))
    }
}
