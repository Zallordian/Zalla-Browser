import XCTest
@testable import Zalla

/// Build 52: dead Settings rows, hidden rows, honest Toolbar Style, and How To directions that match Settings.
final class Build52SettingsFixTests: XCTestCase {
    func testDefaultBrowserRowIsHiddenUntilEntitled() {
        XCTAssertEqual(SettingsRowID.defaultBrowser.isShown, FeatureFlags.defaultBrowserEntitled)
        if !FeatureFlags.defaultBrowserEntitled {
            XCTAssertFalse(SettingsPage.general.shownMainRows.contains(.defaultBrowser))
            XCTAssertNil(SettingsRowID.defaultBrowser.drawnRow)
        }
    }

    func testWidgetsIsDrawnOnce() {
        let shown = SettingsPage.homeAndNewTab.shownMainRows + SettingsPage.homeAndNewTab.shownMoreRows
        XCTAssertEqual(shown.filter { $0 == .widgets || $0 == .addWidgets }, [.widgets])
        XCTAssertEqual(SettingsRowID.addWidgets.drawnRow, .widgets)
        XCTAssertTrue(SettingsRowID.searchResults("add widgets").flatMap(\.rows).compactMap(\.drawnRow).contains(.widgets))
    }

    func testEveryPageStillDrawsSomething() {
        for page in SettingsPage.allCases {
            XCTAssertFalse((page.shownMainRows + page.shownMoreRows).isEmpty, "\(page) draws no rows")
        }
    }

    func testDestructiveRowsStayOnPrivacyPage() {
        XCTAssertTrue(SettingsPage.privacy.shownMainRows.contains(.resetApp))
        XCTAssertTrue(SettingsPage.privacy.shownMainRows.contains(.clearData))
    }

    func testResetCopyMentionsDownloadsAndBookmarks() {
        XCTAssertTrue(SettingsCopy.resetMessage.contains("downloads"))
        XCTAssertTrue(SettingsCopy.resetMessage.contains("Bookmarks are kept"))
        XCTAssertTrue(SettingsRowID.resetApp.subtitle?.contains("downloads") == true)
        XCTAssertTrue(SettingsPage.privacy.footer?.contains("deletes your tabs, history, downloads") == true)
    }

    func testPickingClassicOrCompactLeavesSafariStyle() {
        XCTAssertEqual(BarLayout.layoutAfterPicking(style: .compact, current: .safari, placement: .bottom), .classic)
        XCTAssertEqual(BarLayout.layoutAfterPicking(style: .classic, current: .safari, placement: .bottom), .classic)
        XCTAssertEqual(BarLayout.layoutAfterPicking(style: .quickAction, current: .safari, placement: .bottom), .safari)
        XCTAssertEqual(BarLayout.layoutAfterPicking(style: .compact, current: .safari, placement: .top), .safari)
        XCTAssertEqual(BarLayout.layoutAfterPicking(style: .compact, current: .classic, placement: .bottom), .classic)
    }

    func testSettingsPathsUsePageTitles() {
        XCTAssertEqual(SettingsRowID.privacyShield.settingsPath, "Settings, Privacy and Security, Privacy Shield")
        XCTAssertEqual(SettingsRowID.pullToRefresh.settingsLocation, "Settings, Toolbar and Tabs, More options")
        XCTAssertEqual(SettingsRowID.location.settingsPath, "Settings, Search, Location")
    }

    func testHowToDirectionsPointAtRealPages() {
        let pageTitles = Set(SettingsPage.allCases.map(\.title))
        let stale = ["Settings, Browsing", "Settings, Privacy,", "Settings, Privacy.", "Home personalization",
                     "Open Premium", "Appearance, Toolbar", "Settings, How to"]
        var lines = HowToTopic.allCases.flatMap(\.steps)
        lines.append(ChromeModeTips.quickActionMessage)
        for line in lines {
            for phrase in stale {
                XCTAssertFalse(line.contains(phrase), "Stale direction \(phrase) in: \(line)")
            }
            XCTAssertFalse(line.contains("\u{2014}"), "Em dash in: \(line)")
            // Any "Settings, X" direction names a real page.
            if let range = line.range(of: "Settings, ") {
                let rest = line[range.upperBound...]
                XCTAssertTrue(pageTitles.contains { rest.hasPrefix($0) }, "Unknown Settings page in: \(line)")
            }
        }
    }
}
