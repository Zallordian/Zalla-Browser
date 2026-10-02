import XCTest
@testable import Zalla

final class QuickThemeTests: XCTestCase {
    private func action(_ id: ZallaThemeID, unlocked: Bool, fullLook: Bool = true) -> QuickTheme.Action {
        QuickTheme.action(for: id, unlocked: unlocked, fullLook: fullLook)
    }

    func testLockedPremiumThemesOpenUnlockAndApplyNothing() {
        for id in [ZallaThemeID.volcano, .deepOcean, .arcade, .jungle] {
            XCTAssertEqual(action(id, unlocked: false), .needsUnlock, id.rawValue)
            XCTAssertEqual(action(id, unlocked: false, fullLook: false), .needsUnlock, id.rawValue)
        }
    }

    func testUnlockedPackThemesApplyTheWholePack() {
        let cases: [(ZallaThemeID, String)] = [
            (.volcano, "volcano"), (.deepOcean, "deepocean"), (.arcade, "arcade"), (.jungle, "jungle"), (.space, "space")
        ]
        for (id, pack) in cases {
            guard case .fullPack(let applied) = action(id, unlocked: true) else {
                return XCTFail("\(id.rawValue) should apply its pack")
            }
            XCTAssertEqual(applied.id, pack)
            XCTAssertEqual(applied.themeID, id)
            XCTAssertEqual(applied.icon, id.suggestedAppIcon)
            XCTAssertNotNil(NewTabCatalog.preset(id: applied.backgroundPresetID))
        }
    }

    func testFreeAccentsStayFreeAndOnlySetTheAccent() {
        for id in [ZallaThemeID.zallaRed, .ocean, .forest, .orange, .yellow, .green, .blue, .indigo, .violet] {
            XCTAssertEqual(action(id, unlocked: false), .accentOnly, id.rawValue)
            XCTAssertEqual(action(id, unlocked: true), .accentOnly, id.rawValue)
        }
    }

    func testSpaceAccentStaysFreeWithoutUnlock() {
        XCTAssertFalse(ZallaThemeID.space.requiresUnlock)
        XCTAssertEqual(action(.space, unlocked: false), .accentOnly, "Only the accent; the pack look needs Unlock")
    }

    func testTurningTheSwitchOffMakesEverySwatchAccentOnly() {
        for id in ZallaThemeID.allCases {
            let result = action(id, unlocked: true, fullLook: false)
            XCTAssertEqual(result, .accentOnly, id.rawValue)
        }
    }

    func testEveryFeaturedSwatchHasADefinedAction() {
        for id in ZallaThemeID.featured {
            switch action(id, unlocked: true) {
            case .needsUnlock: XCTFail("Unlocked never needs Unlock: \(id.rawValue)")
            case .accentOnly, .fullPack: break
            }
        }
    }

    func testDefaultsAndKey() {
        XCTAssertTrue(QuickTheme.defaultEnabled)
        XCTAssertEqual(QuickTheme.storageKey, "quickThemeFullLook")
    }
}
