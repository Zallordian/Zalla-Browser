import XCTest
@testable import Zalla

final class ToolbarLayoutTests: XCTestCase {
    func testDefaultsMatchBuiltInLayouts() {
        let layout = ToolbarLayout.default
        XCTAssertEqual(layout.classic, [.back, .forward, .share, .tabs, .menu])
        XCTAssertEqual(layout.compact, [.back, .forward, .address, .tabs, .menu])
        XCTAssertEqual(layout.compactLeading, [.back, .forward])
        XCTAssertEqual(layout.compactTrailing, [.tabs, .menu])
        XCTAssertEqual(layout.quickActionBar, [.tabs, .menu])
        XCTAssertEqual(layout.quickActionFan, [.back, .forward, .reload, .tabs, .newTab, .share])
        XCTAssertFalse(layout.quickActionFan.contains(.menu), "Menu has its own button beside Tabs")
        XCTAssertEqual(ToolbarLayout.decode(Data()), .default)
    }

    func testMenuIsRequiredAndAddressIsPinned() {
        let layout = ToolbarLayout.default
        XCTAssertFalse(layout.canRemove(.menu, from: .classic))
        XCTAssertFalse(layout.canRemove(.menu, from: .compact))
        XCTAssertTrue(layout.canRemove(.menu, from: .quickActionFan))
        XCTAssertFalse(layout.canRemove(.menu, from: .quickActionBar))
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
        XCTAssertFalse(layout.canAdd(to: .quickActionBar), "Tabs and Menu fill the Quick Action bar")
        layout.remove(atOffsets: IndexSet(integer: 0), from: .quickActionBar)
        XCTAssertEqual(layout.quickActionBar, [.menu])
        XCTAssertTrue(layout.canAdd(to: .quickActionBar))
        layout.add(.newTab, to: .quickActionBar)
        XCTAssertEqual(layout.quickActionBar, [.newTab, .menu])
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
        XCTAssertEqual(layout.compact, [.forward, .address, .back, .tabs, .menu])
        XCTAssertEqual(layout.compactLeading, [.forward])
        layout.reset(.classic)
        layout.reset(.compact)
        XCTAssertEqual(layout, .default)
    }

    func testOlderQuickActionLayoutsMoveMenuOutOfTheFan() {
        let old = Data(#"{"quickActionBar":["tabs"],"quickActionFan":["back","forward","reload","tabs","newTab","share","menu"]}"#.utf8)
        let decoded = ToolbarLayout.decode(old)
        XCTAssertEqual(decoded.quickActionBar, [.tabs, .menu])
        XCTAssertEqual(decoded.quickActionFan, [.back, .forward, .reload, .tabs, .newTab, .share])
    }

    func testPersistenceRoundTrip() {
        var layout = ToolbarLayout.default
        layout.remove(atOffsets: IndexSet(integer: 0), from: .quickActionBar)
        layout.add(.find, to: .quickActionBar)
        XCTAssertEqual(layout.quickActionBar, [.find, .menu])
        layout.remove(atOffsets: IndexSet(integer: 2), from: .classic)
        let restored = ToolbarLayout.decode(layout.encoded())
        XCTAssertEqual(restored, layout)
        XCTAssertEqual(ToolbarLayout.decode(Data("not json".utf8)), .default)
        let partial = Data(#"{"classic":["reload","someFutureItem"]}"#.utf8)
        let decoded = ToolbarLayout.decode(partial)
        XCTAssertEqual(decoded.classic, [.reload, .menu])
        XCTAssertEqual(decoded.compact, ToolbarLayout.defaultCompact)
    }

    func testCompactDefaultSwapsShareForTabsAndKeepsEverythingElse() {
        XCTAssertEqual(ToolbarLayout.legacyDefaultCompact, [.back, .forward, .address, .share, .menu])
        XCTAssertEqual(ToolbarLayout.defaultCompact, [.back, .forward, .address, .tabs, .menu])
        XCTAssertEqual(ToolbarLayout.default.buttonCount(for: .compact), 4)
        XCTAssertEqual(ToolbarLayout.defaultClassic, [.back, .forward, .share, .tabs, .menu], "Classic is unchanged")
        XCTAssertEqual(ToolbarLayout.defaultQuickActionBar, [.tabs, .menu])
        XCTAssertEqual(ToolbarLayout.sanitized(ToolbarLayout.defaultCompact, for: .compact), ToolbarLayout.defaultCompact)
    }

    func testMigrationMovesAnUntouchedOldCompactBarOnly() {
        var old = ToolbarLayout.default
        old.setItems(ToolbarLayout.legacyDefaultCompact, for: .compact)
        old.add(.find, to: .classic)
        let migrated = ToolbarLayout.migratedLegacyDefaults(old.encoded())
        XCTAssertNotNil(migrated)
        let layout = ToolbarLayout.decode(migrated ?? Data())
        XCTAssertEqual(layout.compact, ToolbarLayout.defaultCompact)
        XCTAssertEqual(layout.classic, old.classic, "Other bars keep the user's choices")

        var custom = ToolbarLayout.default
        custom.setItems([.back, .address, .share, .reload, .menu], for: .compact)
        XCTAssertNil(ToolbarLayout.migratedLegacyDefaults(custom.encoded()), "A real customization is left alone")
        XCTAssertNil(ToolbarLayout.migratedLegacyDefaults(Data()), "Nothing stored already means the new default")
        XCTAssertNil(ToolbarLayout.migratedLegacyDefaults(Data("not json".utf8)))
    }

    func testMigrationRunsOnceAndOnlyFromStoredOldDefaults() {
        let suite = "ToolbarLayoutTests.migration"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        var old = ToolbarLayout.default
        old.setItems(ToolbarLayout.legacyDefaultCompact, for: .compact)
        old.add(.find, to: .classic)
        defaults.set(old.encoded(), forKey: ToolbarLayout.storageKey)
        ToolbarLayout.migrateLegacyDefaults(in: defaults)
        let first = ToolbarLayout.decode(defaults.data(forKey: ToolbarLayout.storageKey) ?? Data())
        XCTAssertEqual(first.compact, ToolbarLayout.defaultCompact)
        XCTAssertTrue(defaults.bool(forKey: ToolbarLayout.migrationKey))

        // A later, deliberate choice of the old bar is not rewritten.
        var chosen = first
        chosen.setItems(ToolbarLayout.legacyDefaultCompact, for: .compact)
        defaults.set(chosen.encoded(), forKey: ToolbarLayout.storageKey)
        ToolbarLayout.migrateLegacyDefaults(in: defaults)
        XCTAssertEqual(ToolbarLayout.decode(defaults.data(forKey: ToolbarLayout.storageKey) ?? Data()).compact,
                       ToolbarLayout.legacyDefaultCompact)
        defaults.removePersistentDomain(forName: suite)
    }

    func testMigrationCollapsesToEmptyDataWhenNothingElseDiffers() {
        var old = ToolbarLayout.default
        old.setItems(ToolbarLayout.legacyDefaultCompact, for: .compact)
        XCTAssertEqual(ToolbarLayout.migratedLegacyDefaults(old.encoded()), Data())
    }
}
