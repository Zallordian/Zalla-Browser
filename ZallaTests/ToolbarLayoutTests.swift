import XCTest
@testable import Zalla

final class ToolbarLayoutTests: XCTestCase {
    func testDefaultsMatchBuiltInLayouts() {
        let layout = ToolbarLayout.default
        XCTAssertEqual(layout.classic, [.back, .forward, .share, .tabs, .menu])
        XCTAssertEqual(layout.compact, [.back, .forward, .address, .share, .menu])
        XCTAssertEqual(layout.compactLeading, [.back, .forward])
        XCTAssertEqual(layout.compactTrailing, [.share, .menu])
        XCTAssertEqual(layout.quickActionBar, [.tabs])
        XCTAssertEqual(layout.quickActionFan, [.back, .forward, .reload, .tabs, .newTab, .share, .menu])
        XCTAssertEqual(ToolbarLayout.decode(Data()), .default)
    }

    func testMenuIsRequiredAndAddressIsPinned() {
        let layout = ToolbarLayout.default
        XCTAssertFalse(layout.canRemove(.menu, from: .classic))
        XCTAssertFalse(layout.canRemove(.menu, from: .compact))
        XCTAssertFalse(layout.canRemove(.menu, from: .quickActionFan))
        XCTAssertTrue(layout.canRemove(.menu, from: .quickActionBar))
        XCTAssertFalse(layout.canRemove(.address, from: .compact))

        var edited = layout
        edited.remove(atOffsets: IndexSet(integersIn: 0..<5), from: .classic)
        XCTAssertEqual(edited.classic, [.menu])
        edited.remove(atOffsets: IndexSet(integersIn: 0..<5), from: .compact)
        XCTAssertEqual(edited.compact, [.address, .menu])
        XCTAssertEqual(ToolbarLayout.sanitized([.back], for: .classic), [.back, .menu])
        XCTAssertEqual(ToolbarLayout.sanitized([.address, .back], for: .classic), [.back, .menu])
        XCTAssertFalse(layout.available(for: .compact).contains(.address))
    }

    func testLimitsAreEnforced() {
        var layout = ToolbarLayout.default
        XCTAssertTrue(layout.canAdd(to: .classic))
        layout.add(.reload, to: .classic)
        XCTAssertEqual(layout.classic, [.back, .forward, .share, .tabs, .reload, .menu])
        XCTAssertFalse(layout.canAdd(to: .classic))
        layout.add(.newTab, to: .classic)
        XCTAssertEqual(layout.classic.count, ToolbarEditTarget.classic.limit)

        XCTAssertFalse(layout.canAdd(to: .compact), "Compact is full by default")
        XCTAssertFalse(layout.canAdd(to: .quickActionFan), "The fan is full by default")
        XCTAssertTrue(layout.canAdd(to: .quickActionBar))
        layout.add(.newTab, to: .quickActionBar)
        XCTAssertFalse(layout.canAdd(to: .quickActionBar))

        let tooMany: [ToolbarItemKind] = [.back, .forward, .reload, .share, .tabs, .newTab, .find, .menu]
        let clean = ToolbarLayout.sanitized(tooMany, for: .classic)
        XCTAssertEqual(clean.count, 6)
        XCTAssertTrue(clean.contains(.menu))
        XCTAssertEqual(ToolbarLayout.sanitized([.back, .back, .menu], for: .classic), [.back, .menu])
    }

    func testMoveAndReset() {
        var layout = ToolbarLayout.default
        layout.move(fromOffsets: IndexSet(integer: 4), toOffset: 0, in: .classic)
        XCTAssertEqual(layout.classic, [.menu, .back, .forward, .share, .tabs])
        layout.move(fromOffsets: IndexSet(integer: 0), toOffset: 3, in: .compact)
        XCTAssertEqual(layout.compact, [.forward, .address, .back, .share, .menu])
        XCTAssertEqual(layout.compactLeading, [.forward])
        layout.reset(.classic)
        layout.reset(.compact)
        XCTAssertEqual(layout, .default)
    }

    func testPersistenceRoundTrip() {
        var layout = ToolbarLayout.default
        layout.add(.find, to: .quickActionBar)
        layout.remove(atOffsets: IndexSet(integer: 2), from: .classic)
        let restored = ToolbarLayout.decode(layout.encoded())
        XCTAssertEqual(restored, layout)
        XCTAssertEqual(ToolbarLayout.decode(Data("not json".utf8)), .default)
        let partial = Data(#"{"classic":["reload","someFutureItem"]}"#.utf8)
        let decoded = ToolbarLayout.decode(partial)
        XCTAssertEqual(decoded.classic, [.reload, .menu])
        XCTAssertEqual(decoded.compact, ToolbarLayout.defaultCompact)
    }
}
