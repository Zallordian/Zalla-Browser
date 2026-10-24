import XCTest
@testable import Zalla

final class BrowsingPolishTests: XCTestCase {
    func testKeysAreNewAndDefaultsAreOn() {
        XCTAssertEqual(BrowsingPolish.allKeys, ["pillSwipeSwitchesTabs", "pageSnapshotPreviews", "browsingHaptics",
                                                "safariBarQuietAccent", "pillTitleCrossfade"])
        XCTAssertTrue(BrowsingPolish.pillSwipeDefault)
        XCTAssertTrue(BrowsingPolish.snapshotsDefault)
        XCTAssertTrue(BrowsingPolish.hapticsDefault)
        XCTAssertTrue(BrowsingPolish.quietAccentDefault)
        XCTAssertTrue(BrowsingPolish.titleCrossfadeDefault)
    }

    func testMissingValueReadsAsDefault() {
        let defaults = UserDefaults(suiteName: "BrowsingPolishTests")!
        defaults.removePersistentDomain(forName: "BrowsingPolishTests")
        XCTAssertTrue(BrowsingPolish.isOn(BrowsingPolish.hapticsKey, default: true, in: defaults))
        XCTAssertFalse(BrowsingPolish.isOn(BrowsingPolish.hapticsKey, default: false, in: defaults))
        defaults.set(false, forKey: BrowsingPolish.hapticsKey)
        XCTAssertFalse(BrowsingPolish.isOn(BrowsingPolish.hapticsKey, default: true, in: defaults))
    }

    func testEveryToggleHasASettingsRow() {
        for key in BrowsingPolish.allKeys {
            XCTAssertTrue(SettingsRowID.coveredKeys.contains(key), key)
        }
    }

    func testHapticsRespectTheToggle() {
        XCTAssertTrue(BrowsingHaptic.shouldPlay(.tabSwitch, enabled: true))
        XCTAssertFalse(BrowsingHaptic.shouldPlay(.tabSwitch, enabled: false))
        XCTAssertFalse(BrowsingHaptic.shouldPlay(.pullToRefresh, enabled: false))
    }

    func testBackAppearsOnlyOnTheSameTab() {
        XCTAssertTrue(BrowsingHaptic.backAppeared(was: false, now: true, sameTab: true))
        XCTAssertFalse(BrowsingHaptic.backAppeared(was: true, now: true, sameTab: true))
        XCTAssertFalse(BrowsingHaptic.backAppeared(was: true, now: false, sameTab: true))
        XCTAssertFalse(BrowsingHaptic.backAppeared(was: false, now: true, sameTab: false))
    }
}

final class TabSwipeTests: XCTestCase {
    private let ids = ["a", "b", "c"]

    func testNeighbors() {
        XCTAssertEqual(TabSwipe.neighbor(in: ids, current: "b", translation: -50), "c")
        XCTAssertEqual(TabSwipe.neighbor(in: ids, current: "b", translation: 50), "a")
        XCTAssertNil(TabSwipe.neighbor(in: ids, current: "c", translation: -50))
        XCTAssertNil(TabSwipe.neighbor(in: ids, current: "a", translation: 50))
        XCTAssertNil(TabSwipe.neighbor(in: ids, current: "b", translation: 0))
        XCTAssertNil(TabSwipe.neighbor(in: ids, current: "z", translation: 10))
    }

    func testCommit() {
        XCTAssertTrue(TabSwipe.shouldCommit(translation: -150, predictedEnd: -150, width: 400, hasNeighbor: true))
        XCTAssertFalse(TabSwipe.shouldCommit(translation: -40, predictedEnd: -50, width: 400, hasNeighbor: true))
        XCTAssertTrue(TabSwipe.shouldCommit(translation: -40, predictedEnd: -400, width: 400, hasNeighbor: true), "A flick switches")
        XCTAssertFalse(TabSwipe.shouldCommit(translation: -300, predictedEnd: -400, width: 400, hasNeighbor: false))
    }

    func testRubberBandAtTheEnds() {
        XCTAssertEqual(TabSwipe.displayedOffset(translation: 100, hasNeighbor: true), 100)
        XCTAssertEqual(TabSwipe.displayedOffset(translation: 100, hasNeighbor: false), 25)
    }
}

final class LRUStoreTests: XCTestCase {
    func testEvictsLeastRecentlyUsed() {
        var store = LRUStore<Int>(capacity: 2)
        store.set(1, for: "a")
        store.set(2, for: "b")
        XCTAssertEqual(store.value(for: "a"), 1)
        store.set(3, for: "c")
        XCTAssertNil(store.value(for: "b"))
        XCTAssertEqual(store.value(for: "a"), 1)
        XCTAssertEqual(store.value(for: "c"), 3)
        XCTAssertEqual(store.count, 2)
    }

    func testRemoveAllAndZeroCapacity() {
        var store = LRUStore<Int>(capacity: 3)
        store.set(1, for: "a")
        store.removeAll()
        XCTAssertEqual(store.count, 0)
        var none = LRUStore<Int>(capacity: 0)
        none.set(1, for: "a")
        XCTAssertNil(none.value(for: "a"))
    }

    func testSnapshotCacheIsBoundedAndWebOnly() {
        XCTAssertLessThanOrEqual(PageSnapshotCache.capacity, 16)
        XCTAssertNil(PageSnapshotCache.key(for: URL(string: "about:blank")))
        XCTAssertNil(PageSnapshotCache.key(for: nil))
        XCTAssertEqual(PageSnapshotCache.key(for: URL(string: "https://zalla.gg/")), "https://zalla.gg/")
    }

    func testPrivateTabsAreNeverCached() {
        let cache = PageSnapshotCache.shared
        cache.removeAll()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        let url = URL(string: "https://example.com/private")
        cache.store(image, for: url, isPrivate: true)
        XCTAssertNil(cache.image(for: url))
        cache.removeAll()
    }
}

final class Build44SettingsTests: XCTestCase {
    func testMoreOptionsRows() {
        let tucked = SettingsRowID.allCases.filter(\.inMoreOptions)
        XCTAssertTrue(tucked.contains(.pillSwipeTabs))
        XCTAssertTrue(tucked.contains(.networkSpeed))
        XCTAssertFalse(tucked.contains(.searchEngine))
        XCTAssertFalse(tucked.contains(.clearData))
        XCTAssertFalse(tucked.contains(.barLayout))
        for group in SettingsGroup.allCases {
            XCTAssertTrue(group.rows.contains { !$0.inMoreOptions }, "\(group) would be all hidden")
        }
    }

    func testCopyHasNoDashes() {
        let rows: [SettingsRowID] = [.pillSwipeTabs, .pageSnapshots, .browsingHaptics, .quietAccent, .titleCrossfade]
        for row in rows {
            for text in [row.title, row.subtitle ?? "", SettingsRowID.moreOptionsTitle] {
                XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), text)
            }
        }
    }
}
