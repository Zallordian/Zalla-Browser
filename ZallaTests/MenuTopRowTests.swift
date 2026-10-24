import XCTest
@testable import Zalla

final class MenuTopRowTests: XCTestCase {
    func testDefaultActions() {
        XCTAssertEqual(MenuTopRow.default.items, [.bookmark, .history, .burn, .newPrivateTab])
        XCTAssertEqual(MenuTopRow.build26DefaultItems, [.back, .forward, .reload, .share, .settings])
        XCTAssertEqual(MenuTopRow.legacyDefaultItems, [.back, .forward, .reload, .tabs, .settings])
        XCTAssertTrue(MenuTopRow.default.isDefault)
        XCTAssertEqual(MenuTopRow.storageKey, "menuTopRow", "Same key as the old Menu row, so saved choices carry over")
        XCTAssertEqual(MenuTopRow.maxItems, 8)
    }

    func testEveryItemHasNamesAndIcons() {
        XCTAssertEqual(MenuTopRowItem.allCases.count, 17)
        for item in MenuTopRowItem.allCases {
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.shortTitle.isEmpty)
            XCTAssertFalse(item.symbolName.isEmpty)
            XCTAssertFalse(item.title.contains("\u{2014}") || item.title.contains("\u{2013}"))
        }
        XCTAssertEqual(Set(MenuTopRowItem.allCases.map(\.rawValue)).count, 17)
    }

    func testSanitizedDropsDuplicatesCapsAndFallsBack() {
        XCTAssertEqual(MenuTopRow([.back, .back, .tabs]).items, [.back, .tabs])
        XCTAssertEqual(MenuTopRow([]).items, MenuTopRow.defaultItems)
        let many = MenuTopRow(MenuTopRowItem.allCases)
        XCTAssertEqual(many.items, Array(MenuTopRowItem.allCases.prefix(MenuTopRow.maxItems)))
    }

    func testAddRespectsTheLimit() {
        var row = MenuTopRow([.back, .forward, .reload, .tabs, .settings, .share, .home])
        XCTAssertTrue(row.canAdd)
        row.add(.find)
        XCTAssertFalse(row.canAdd)
        row.add(.burn)
        XCTAssertEqual(row.items.count, 8)
        row.add(.back)
        XCTAssertEqual(row.items.filter { $0 == .back }.count, 1)
    }

    func testRemoveKeepsAtLeastOneItem() {
        var row = MenuTopRow([.back, .tabs])
        row.remove(.back)
        XCTAssertEqual(row.items, [.tabs])
        row.remove(.tabs)
        XCTAssertEqual(row.items, [.tabs])
    }

    func testMoveMatchesSwiftUISemantics() {
        var row = MenuTopRow.default
        row.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(row.items, [.history, .burn, .bookmark, .newPrivateTab])
    }

    func testAvailableListsWhatIsMissing() {
        XCTAssertEqual(MenuTopRow.default.available.count + MenuTopRow.default.items.count, MenuTopRowItem.allCases.count)
        XCTAssertTrue(MenuTopRow.default.available.contains(.reader))
    }

    func testDecodeToleratesBadData() {
        XCTAssertEqual(MenuTopRow.decode(Data()), .default)
        XCTAssertEqual(MenuTopRow.decode(Data("not json".utf8)), .default)
        XCTAssertEqual(MenuTopRow.decode(Data("[\"nope\"]".utf8)), .default)
        XCTAssertEqual(MenuTopRow.decode(Data("[\"share\",\"future\",\"back\",\"share\"]".utf8)).items, [.share, .back])
    }

    func testSavedMenuRowDataMigrates() {
        // Never customized: stored as empty data, so it picks up the new My actions default.
        XCTAssertEqual(MenuTopRow.decode(Data()).items, [.bookmark, .history, .burn, .newPrivateTab])
        // A row saved by Build 40 or earlier (a JSON list of names under the same key) keeps every button.
        let saved = Data("[\"back\",\"forward\",\"reload\",\"tabs\",\"settings\",\"downloads\"]".utf8)
        XCTAssertEqual(MenuTopRow.decode(saved).items, [.back, .forward, .reload, .tabs, .settings, .downloads])
        // A chosen old default stays as chosen.
        let chosen = MenuTopRow(MenuTopRow.build26DefaultItems)
        XCTAssertEqual(MenuTopRow.decode(chosen.encoded()).items, MenuTopRow.build26DefaultItems)
        // New actions round trip.
        let fresh = MenuTopRow([.history, .reader, .privacyReport, .desktopSite, .newPrivateTab])
        XCTAssertEqual(MenuTopRow.decode(fresh.encoded()), fresh)
    }
}
