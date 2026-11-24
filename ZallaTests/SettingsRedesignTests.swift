import XCTest
@testable import Zalla

/// Redesign phase 4: one Layout row, page summaries that only name real rows, and search paths that still land.
final class SettingsRedesignTests: XCTestCase {
    func testLayoutReplacesTheThreeToolbarRows() {
        XCTAssertTrue(SettingsRowID.barLayout.isShown)
        XCTAssertFalse(SettingsRowID.addressBar.isShown)
        XCTAssertFalse(SettingsRowID.toolbarStyle.isShown)
        XCTAssertEqual(SettingsRowID.addressBar.drawnRow, .barLayout)
        XCTAssertEqual(SettingsRowID.toolbarStyle.drawnRow, .barLayout)
        XCTAssertEqual(SettingsRowID.barLayout.title, "Layout")
        // The settings those rows owned are still reachable.
        for key in [BarLayout.storageKey, ToolbarStyle.storageKey, AddressBarPlacement.storageKey] {
            XCTAssertTrue(SettingsRowID.coveredKeys.contains(key), key)
        }
    }

    func testSearchingOldNamesFindsLayout() {
        for query in ["toolbar style", "address bar"] {
            let rows = SettingsRowID.searchResults(query).flatMap(\.rows).compactMap(\.drawnRow)
            XCTAssertTrue(rows.contains(.barLayout), "\(query) should find Layout")
        }
    }

    func testHowToPointsAtTheVisibleRow() {
        XCTAssertEqual(SettingsRowID.toolbarStyle.settingsPath, "Settings, Toolbar and Tabs, Layout")
        XCTAssertEqual(SettingsRowID.privacyShield.settingsPath, "Settings, Privacy and Security, Privacy Shield")
    }

    func testPageSummariesOnlyNameShownRows() {
        for page in SettingsPage.allCases {
            let line = page.contentsLine
            XCTAssertFalse(line.isEmpty, "\(page) needs a summary")
            let shownTitles = Set(page.shownMainRows.compactMap(\.drawnRow).map(\.title))
            for title in line.components(separatedBy: ", ") {
                XCTAssertTrue(shownTitles.contains(title), "\(page) summary names \(title), which isn't on the page")
            }
            XCTAssertFalse(line.contains(SettingsRowID.resetApp.title))
        }
    }

    func testCopyIsPlain() {
        for text in [BarLayout.settingsFooter, SearchEnginePrivacy.customNote] + SettingsPage.allCases.map(\.contentsLine) {
            XCTAssertFalse(text.contains("\u{2014}"), text)
            XCTAssertFalse(text.contains("\u{2013}"), text)
        }
    }
}
