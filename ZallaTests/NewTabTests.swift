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

final class ThemePackTests: XCTestCase {
    func testPacksPointAtRealThingsAndNeedUnlock() {
        XCTAssertEqual(ThemePacks.all.map(\.id), ["space", "jungle", "volcano", "deepocean", "arcade", "neoncity", "arctic", "cherryblossom"])
        for pack in ThemePacks.all {
            let preset = NewTabCatalog.preset(id: pack.backgroundPresetID)
            XCTAssertNotNil(preset, pack.id)
            XCTAssertTrue(preset?.requiresUnlock == true)
            XCTAssertEqual(pack.themeID.suggestedAppIcon, pack.icon)
            XCTAssertFalse(pack.tagline.contains("\u{2014}"))
        }
        XCTAssertTrue(ZallaThemeID.jungle.requiresUnlock)
        XCTAssertTrue(AppIconPreference.jungle.requiresUnlock)
        XCTAssertFalse(ZallaThemeID.space.requiresUnlock)
        for id in [ZallaThemeID.volcano, .deepOcean, .arcade, .neonCity, .arctic, .cherryBlossom] {
            XCTAssertTrue(id.requiresUnlock, id.rawValue)
            XCTAssertTrue(id.suggestedAppIcon.requiresUnlock, id.rawValue)
        }
        XCTAssertFalse(ZallaThemeID.ocean.requiresUnlock, "The free Ocean accent is unchanged")
        XCTAssertFalse(AppIconPreference.ocean.requiresUnlock)
    }

    func testTransitionRules() {
        let base = { (unlocked: Bool, on: Bool, reduce: Bool, custom: Bool) in
            ThemePacks.activeTransition(themeID: "space", useCustomAccent: custom, unlocked: unlocked, enabled: on,
                                        reduceMotion: reduce, speed: .normal)
        }
        XCTAssertEqual(base(true, true, false, false)?.kind, .space)
        XCTAssertEqual(base(true, true, false, false)?.style, .full)
        XCTAssertNil(base(false, true, false, false))
        XCTAssertNil(base(true, false, false, false))
        XCTAssertEqual(base(true, true, true, false)?.style, .fade, "Reduce Motion becomes a quick fade")
        XCTAssertNil(base(true, true, false, true))
        XCTAssertNil(ThemePacks.activeTransition(themeID: "ocean", useCustomAccent: false, unlocked: true, enabled: true,
                                                 reduceMotion: false, speed: .normal))
        XCTAssertEqual(ThemePacks.activeTransition(themeID: "jungle", useCustomAccent: false, unlocked: true, enabled: true,
                                                   reduceMotion: false, speed: .fast)?.kind, .jungle)
    }

    func testCustomColorsNeverPickALockedIcon() {
        XCTAssertNotEqual(ZallaTheme.closestAppIcon(forCustomHex: "8DB63C"), .jungle)
        for hex in ["E8481C", "14A3B8", "FF4FB0", "E83CFF", "5AB8E8", "F0709C"] {
            XCTAssertFalse(ZallaTheme.closestAppIcon(forCustomHex: hex).requiresUnlock, hex)
        }
    }
}
