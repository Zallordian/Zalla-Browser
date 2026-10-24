import XCTest
@testable import Zalla

/// Build 48: each seasonal theme has its own light refresh flair.
final class SeasonalFlairTests: XCTestCase {
    func testEverySeasonalThemeHasFlair() {
        let expected: [ZallaThemeID: ThemeTransitionKind] = [
            .winter: .snowfall, .christmas: .snowfall, .halloween: .bats, .harvest: .leaves,
            .fourthOfJuly: .fireworks, .newYear: .fireworks, .valentines: .hearts, .stPatricks: .shamrocks,
            .spring: .petals, .easter: .petals, .summer: .sunShimmer, .memorialDay: .stars
        ]
        XCTAssertEqual(Set(expected.keys), Set(ZallaThemeID.seasonal))
        for (id, kind) in expected {
            XCTAssertEqual(SeasonalFlair.kind(for: id), kind, id.rawValue)
            XCTAssertTrue(kind.isSeasonal)
            XCTAssertFalse(SeasonalFlair.particles(for: kind).isEmpty)
        }
        for id in ZallaThemeID.allCases where !id.isSeasonal {
            XCTAssertNil(SeasonalFlair.kind(for: id), id.rawValue)
        }
        XCTAssertFalse(ThemeTransitionKind.arctic.isSeasonal)
    }

    func testPlaysOnlyForTheCurrentSeasonalThemeAndIsFree() {
        let plan = ThemePacks.activeTransition(themeID: "halloween", useCustomAccent: false, unlocked: false,
                                               enabled: true, reduceMotion: false, speed: .normal)
        XCTAssertEqual(plan?.kind, .bats)
        XCTAssertEqual(plan?.style, .full)
        XCTAssertNil(ThemePacks.activeTransition(themeID: "halloween", useCustomAccent: true, unlocked: true,
                                                 enabled: true, reduceMotion: false, speed: .normal))
        XCTAssertNil(ThemePacks.activeTransition(themeID: "halloween", useCustomAccent: false, unlocked: true,
                                                 enabled: false, reduceMotion: false, speed: .normal))
        XCTAssertNil(ThemePacks.activeTransition(themeID: "zallaRed", useCustomAccent: false, unlocked: true,
                                                 enabled: true, reduceMotion: false, speed: .normal))
        // Pro packs still need Unlock.
        XCTAssertNil(ThemePacks.activeTransition(themeID: "arctic", useCustomAccent: false, unlocked: false,
                                                 enabled: true, reduceMotion: false, speed: .normal))
    }

    func testReduceMotionIsAStillFade() {
        let plan = ThemePacks.activeTransition(themeID: "christmas", useCustomAccent: false, unlocked: false,
                                               enabled: true, reduceMotion: true, speed: .normal)
        XCTAssertEqual(plan?.style, .fade)
    }

    func testParticlesStayDeterministicAndFinish() {
        for kind in [ThemeTransitionKind.snowfall, .bats, .leaves, .fireworks, .hearts, .shamrocks, .petals, .sunShimmer, .stars] {
            XCTAssertEqual(SeasonalFlair.particles(for: kind), SeasonalFlair.particles(for: kind))
            XCTAssertLessThanOrEqual(SeasonalFlair.particles(for: kind).count, 50, "Kept light")
            for p in SeasonalFlair.particles(for: kind) {
                XCTAssertNil(SeasonalFlair.state(of: p, kind: kind, progress: 1), "Nothing is left at the end")
                XCTAssertNil(SeasonalFlair.state(of: p, kind: kind, progress: 0))
            }
            let mid = SeasonalFlair.particles(for: kind).compactMap { SeasonalFlair.state(of: $0, kind: kind, progress: 0.5) }
            XCTAssertFalse(mid.isEmpty, "\(kind)")
        }
        XCTAssertTrue(SeasonalFlair.particles(for: .jungle).isEmpty)
    }
}
