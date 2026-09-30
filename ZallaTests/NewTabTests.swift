import XCTest
@testable import Zalla

final class NewTabTests: XCTestCase {
    func testThereAreTwentyFiveSayingsWithoutEmDashes() {
        XCTAssertEqual(NewTabSayings.all.count, 25)
        XCTAssertEqual(Set(NewTabSayings.all).count, 25)
        XCTAssertFalse(NewTabSayings.all.contains { $0.contains("\u{2014}") })
        XCTAssertFalse(NewTabSayings.all.contains("Your tabs, your rhythm."))
    }

    func testDeckNeverRepeatsBackToBackAndCoversEveryLine() {
        var deck = SayingDeck(lines: NewTabSayings.all)
        var generator = SystemRandomNumberGenerator()
        var picks: [String] = []
        for _ in 0..<100 { picks.append(deck.next(using: &generator)) }
        for index in 1..<picks.count {
            XCTAssertNotEqual(picks[index], picks[index - 1])
        }
        for start in stride(from: 0, to: 100, by: 25) {
            XCTAssertEqual(Set(picks[start..<(start + 25)]).count, 25, "Each round shows every saying once")
        }
    }

    func testBackgroundStorageRoundTrip() {
        XCTAssertEqual(NewTabBackground(storageValue: nil), .standard)
        XCTAssertEqual(NewTabBackground(storageValue: "garbage"), .standard)
        XCTAssertEqual(NewTabBackground(storageValue: "preset:crimson"), .preset("crimson"))
        XCTAssertEqual(NewTabBackground(storageValue: "preset:missing"), .standard)
        XCTAssertEqual(NewTabBackground(storageValue: NewTabBackground.photo.storageValue), .photo)
        XCTAssertEqual(NewTabBackground(storageValue: NewTabBackground.preset("ocean").storageValue), .preset("ocean"))
    }

    func testPacksNeedUnlockButFreePresetsDoNot() {
        let free = NewTabBackground.preset("crimson")
        XCTAssertEqual(free.effective(unlocked: false, hasPhoto: false), free)
        let packed = NewTabBackground.preset("ocean")
        XCTAssertEqual(packed.effective(unlocked: false, hasPhoto: false), .standard)
        XCTAssertEqual(packed.effective(unlocked: true, hasPhoto: false), packed)
        XCTAssertEqual(NewTabBackground.photo.effective(unlocked: false, hasPhoto: true), .photo)
        XCTAssertEqual(NewTabBackground.photo.effective(unlocked: false, hasPhoto: false), .standard)
    }

    func testCatalogIsConsistent() {
        XCTAssertEqual(Set(NewTabCatalog.all.map(\.id)).count, NewTabCatalog.all.count)
        XCTAssertTrue(NewTabCatalog.free.allSatisfy { !$0.requiresUnlock })
        XCTAssertTrue(NewTabCatalog.packed.allSatisfy(\.requiresUnlock))
        for pack in NewTabCatalog.packs {
            XCTAssertFalse(NewTabCatalog.presets(inPack: pack.id).isEmpty)
        }
    }
}
