import XCTest
@testable import Zalla

final class MenuTopRowTests: XCTestCase {
    func testDefaultRowHasShareBeforeSettings() {
        XCTAssertEqual(MenuTopRow.default.items, [.back, .forward, .reload, .share, .settings])
        XCTAssertEqual(MenuTopRow.legacyDefaultItems, [.back, .forward, .reload, .tabs, .settings])
        XCTAssertFalse(MenuTopRow.default.items.contains(.tabs))
        XCTAssertTrue(MenuTopRow.default.isDefault)
        XCTAssertEqual(MenuTopRow.storageKey, "menuTopRow")
    }

    func testEveryItemHasNamesAndIcons() {
        XCTAssertEqual(MenuTopRowItem.allCases.count, 12)
        for item in MenuTopRowItem.allCases {
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.shortTitle.isEmpty)
            XCTAssertFalse(item.symbolName.isEmpty)
            XCTAssertFalse(item.title.contains("\u{2014}"))
        }
        XCTAssertEqual(MenuTopRowItem.settings.symbolName, "gearshape")
        XCTAssertEqual(Set(MenuTopRowItem.allCases.map(\.rawValue)).count, 12)
    }

    func testSanitizedDropsDuplicatesCapsAndFallsBack() {
        XCTAssertEqual(MenuTopRow([.back, .back, .tabs]).items, [.back, .tabs])
        XCTAssertEqual(MenuTopRow([]).items, MenuTopRow.defaultItems)
        let many = MenuTopRow(MenuTopRowItem.allCases)
        XCTAssertEqual(many.items.count, MenuTopRow.maxItems)
        XCTAssertEqual(many.items, Array(MenuTopRowItem.allCases.prefix(MenuTopRow.maxItems)))
    }

    func testAddRespectsTheLimitAndSkipsDuplicates() {
        var row = MenuTopRow([.back, .forward, .reload, .tabs, .settings])
        XCTAssertTrue(row.canAdd)
        row.add(.share)
        XCTAssertEqual(row.items.last, .share)
        XCTAssertFalse(row.canAdd)
        row.add(.home)
        XCTAssertEqual(row.items.count, 6)
        row.remove(.share)
        row.add(.back)
        XCTAssertEqual(row.items.filter { $0 == .back }.count, 1)
    }

    func testRemoveKeepsAtLeastOneItem() {
        var row = MenuTopRow([.back, .tabs])
        row.remove(.back)
        XCTAssertEqual(row.items, [.tabs])
        XCTAssertFalse(row.canRemove(.tabs))
        row.remove(.tabs)
        XCTAssertEqual(row.items, [.tabs])
        row.remove(atOffsets: IndexSet(integer: 0))
        XCTAssertEqual(row.items, [.tabs])
    }

    func testRemoveAtOffsets() {
        var row = MenuTopRow.default
        row.remove(atOffsets: IndexSet([0, 2]))
        XCTAssertEqual(row.items, [.forward, .share, .settings])
        row.remove(atOffsets: IndexSet(integer: 99))
        XCTAssertEqual(row.items, [.forward, .share, .settings])
    }

    func testAvailableListsWhatIsMissing() {
        let row = MenuTopRow.default
        XCTAssertEqual(row.available, [.tabs, .bookmark, .find, .newTab, .burn, .downloads, .home])
        XCTAssertEqual(MenuTopRow.default.available.count + MenuTopRow.default.items.count, MenuTopRowItem.allCases.count)
    }

    func testMoveMatchesSwiftUISemantics() {
        var row = MenuTopRow.default
        row.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(row.items, [.forward, .reload, .back, .share, .settings])
        row.move(fromOffsets: IndexSet(integer: 4), toOffset: 0)
        XCTAssertEqual(row.items, [.settings, .forward, .reload, .back, .share])
        row.move(fromOffsets: IndexSet(integer: 1), toOffset: 5)
        XCTAssertEqual(row.items, [.settings, .reload, .back, .share, .forward])
        row.move(fromOffsets: IndexSet(integer: 2), toOffset: 2)
        XCTAssertEqual(row.items, [.settings, .reload, .back, .share, .forward])
    }

    func testResetRestoresDefault() {
        var row = MenuTopRow([.share, .burn])
        XCTAssertFalse(row.isDefault)
        row.reset()
        XCTAssertTrue(row.isDefault)
    }

    func testEncodeDecodeRoundTrip() {
        let row = MenuTopRow([.home, .back, .burn, .tabs])
        XCTAssertEqual(MenuTopRow.decode(row.encoded()), row)
    }

    func testDecodeToleratesBadData() {
        XCTAssertEqual(MenuTopRow.decode(Data()), .default)
        XCTAssertEqual(MenuTopRow.decode(Data("not json".utf8)), .default)
        XCTAssertEqual(MenuTopRow.decode(Data("[]".utf8)), .default)
        XCTAssertEqual(MenuTopRow.decode(Data("[\"nope\"]".utf8)), .default)
        let mixed = Data("[\"share\",\"future\",\"back\",\"share\"]".utf8)
        XCTAssertEqual(MenuTopRow.decode(mixed).items, [.share, .back])
    }

    func testNeverCustomizedRowsGetTheNewDefaultAndRealChoicesStay() {
        // The editor stores an unchanged row as empty data, so anyone on the old default has nothing stored.
        XCTAssertEqual(MenuTopRow.decode(Data()).items, [.back, .forward, .reload, .share, .settings])
        // Someone who chose the old row on purpose after the change keeps it.
        let chosen = MenuTopRow(MenuTopRow.legacyDefaultItems)
        XCTAssertFalse(chosen.isDefault)
        XCTAssertEqual(MenuTopRow.decode(chosen.encoded()).items, MenuTopRow.legacyDefaultItems)
        // Tabs is still available to add back.
        XCTAssertTrue(MenuTopRow.default.available.contains(.tabs))
        var row = MenuTopRow.default
        row.reset()
        XCTAssertTrue(row.isDefault)
    }
}
