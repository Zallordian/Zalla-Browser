import XCTest
@testable import Zalla

/// Build 46: the short main Settings screen must still reach every setting, each on exactly one page, and search
/// must find every one of them.
final class SettingsPagesTests: XCTestCase {
    func testEveryRowIsOnExactlyOnePage() {
        for row in SettingsRowID.allCases {
            let pages = SettingsPage.allCases.filter { $0.rows.contains(row) }
            XCTAssertEqual(pages.count, 1, "\(row) is on \(pages.count) pages")
        }
        let total = SettingsPage.allCases.reduce(0) { $0 + $1.rows.count }
        XCTAssertEqual(total, SettingsRowID.allCases.count)
    }

    func testEveryPageIsOnTheMainScreenOnceAndHasRows() {
        let listed = SettingsPage.mainScreenGroups.flatMap { $0 }
        XCTAssertEqual(listed.count, Set(listed).count)
        XCTAssertEqual(Set(listed), Set(SettingsPage.allCases))
        for page in SettingsPage.allCases {
            XCTAssertFalse(page.rows.isEmpty, "\(page) is empty")
            XCTAssertFalse(page.symbol.isEmpty)
        }
    }

    func testEveryRowIsFoundByItsTitle() {
        for row in SettingsRowID.allCases {
            let hits = SettingsRowID.searchResults(row.title).flatMap(\.rows)
            XCTAssertTrue(hits.contains(row), "Search for \(row.title) misses \(row)")
        }
    }

    func testEveryRowIsFoundByEachKeyword() {
        for row in SettingsRowID.allCases {
            for keyword in row.searchKeywords {
                XCTAssertTrue(row.matchesSearch(keyword), "\(row) misses keyword \(keyword)")
            }
        }
    }

    func testSearchIsCaseInsensitiveAndUsesKeywords() {
        XCTAssertTrue(SettingsRowID.searchResults("DARK MODE").flatMap(\.rows).contains(.appearance))
        XCTAssertTrue(SettingsRowID.searchResults("duckduckgo").flatMap(\.rows).contains(.searchEngine))
        XCTAssertTrue(SettingsRowID.searchResults("face id").flatMap(\.rows).contains(.privateTabLock))
        XCTAssertTrue(SettingsRowID.searchResults("   ").isEmpty)
        XCTAssertTrue(SettingsRowID.searchResults("zzqqxx").isEmpty)
    }

    func testEveryStoredKeyIsStillReachableFromAPage() {
        let reachable = Set(SettingsPage.allCases.flatMap(\.rows).flatMap(\.storageKeys))
        XCTAssertEqual(reachable, SettingsRowID.coveredKeys)
    }

    func testCopyHasNoDashesOrVPN() {
        var lines = SettingsPage.allCases.map(\.title) + SettingsPage.allCases.compactMap(\.footer)
        lines += SettingsRowID.allCases.flatMap(\.searchKeywords)
        for line in lines {
            XCTAssertFalse(line.contains("\u{2014}"), "Em dash in: \(line)")
            XCTAssertFalse(line.contains("\u{2013}"), "En dash in: \(line)")
            XCTAssertFalse(line.localizedCaseInsensitiveContains("vpn"), "VPN wording in: \(line)")
        }
    }
}
