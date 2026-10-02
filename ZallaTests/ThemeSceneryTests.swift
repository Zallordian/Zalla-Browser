import XCTest
@testable import Zalla

final class ThemeSceneryTests: XCTestCase {
    private let steps = stride(from: 0.0, through: 1.0, by: 0.05).map { $0 }

    // MARK: Plans for the new kinds

    func testNewKindsFollowTheSameGatingAndTiming() {
        for kind in [ThemeTransitionKind.volcano, .ocean, .arcade] {
            let normal = ThemeTransitionPlan.make(kind: kind, unlocked: true, enabled: true, reduceMotion: false, speed: .normal)
            XCTAssertEqual(normal?.kind, kind)
            XCTAssertEqual(normal?.style, .full)
            XCTAssertEqual(normal?.duration ?? 0, 1.0, accuracy: 0.001)
            XCTAssertEqual(ThemeTransitionPlan.make(kind: kind, unlocked: true, enabled: true, reduceMotion: false, speed: .slow)?.duration ?? 0, 1.5, accuracy: 0.001)
            XCTAssertEqual(ThemeTransitionPlan.make(kind: kind, unlocked: true, enabled: true, reduceMotion: false, speed: .fast)?.duration ?? 0, 0.65, accuracy: 0.001)
            XCTAssertNil(ThemeTransitionPlan.make(kind: kind, unlocked: false, enabled: true, reduceMotion: false, speed: .normal))
            XCTAssertNil(ThemeTransitionPlan.make(kind: kind, unlocked: true, enabled: false, reduceMotion: false, speed: .normal))
            XCTAssertEqual(ThemeTransitionPlan.make(kind: kind, unlocked: true, enabled: true, reduceMotion: true, speed: .normal)?.style, .fade)
        }
    }

    func testPacksPickTheRightTransitions() {
        XCTAssertEqual(ThemePacks.pack(for: "volcano")?.transition, .volcano)
        XCTAssertEqual(ThemePacks.pack(for: "deepOcean")?.transition, .ocean)
        XCTAssertEqual(ThemePacks.pack(for: "arcade")?.transition, .arcade)
        XCTAssertNil(ThemePacks.pack(for: "ocean"), "The free Ocean accent has no pack")
        XCTAssertEqual(ThemePacks.activeTransition(themeID: "arcade", useCustomAccent: false, unlocked: true, enabled: true,
                                                   reduceMotion: false, speed: .normal)?.kind, .arcade)
        XCTAssertNil(ThemePacks.activeTransition(themeID: "volcano", useCustomAccent: false, unlocked: false, enabled: true,
                                                 reduceMotion: false, speed: .normal))
        XCTAssertNil(ThemePacks.activeTransition(themeID: "deepOcean", useCustomAccent: true, unlocked: true, enabled: true,
                                                 reduceMotion: false, speed: .normal))
    }

    func testPackBackgroundsAndIconsExist() {
        for id in ["volcano", "deepocean", "arcade"] {
            XCTAssertFalse(NewTabCatalog.presets(inPack: id).isEmpty, id)
            XCTAssertTrue(NewTabCatalog.presets(inPack: id).allSatisfy { $0.requiresUnlock && $0.decor != NewTabPreset.Decor.none }, id)
        }
        XCTAssertEqual(Set(NewTabCatalog.all.map(\.id)).count, NewTabCatalog.all.count, "Preset ids stay unique")
        XCTAssertEqual(NewTabCatalog.preset(id: "lava")?.decor, .embers)
        XCTAssertEqual(NewTabCatalog.preset(id: "lagoon")?.decor, .bubbles)
        XCTAssertEqual(NewTabCatalog.preset(id: "cabinet")?.decor, .pixels)
    }

    func testIconNamesMatchTheAssets() {
        XCTAssertEqual(AppIconPreference.volcano.alternateIconName, "AppIconVolcano")
        XCTAssertEqual(AppIconPreference.deepOcean.alternateIconName, "AppIconDeepOcean")
        XCTAssertEqual(AppIconPreference.arcade.alternateIconName, "AppIconRetroArcade")
        XCTAssertEqual(AppIconPreference.deepOcean.displayName, "Deep Ocean")
        XCTAssertEqual(AppIconPreference.arcade.displayName, "Retro Arcade")
        XCTAssertEqual(AppIconPreference.jungle.displayName, "Jungle")
        for icon in [AppIconPreference.volcano, .deepOcean, .arcade] {
            XCTAssertTrue(icon.requiresUnlock)
            XCTAssertFalse(icon.rawValue.contains(" "))
        }
        XCTAssertEqual(ZallaThemeID.deepOcean.displayName, "Deep Ocean")
        XCTAssertEqual(ZallaThemeID.arcade.displayName, "Retro Arcade")
    }

    // MARK: Volcano

    func testLavaCoversTheScreenAndThenClearsIt() {
        XCTAssertEqual(VolcanoLava.front(0), 0, accuracy: 0.001)
        XCTAssertGreaterThan(VolcanoLava.front(0.5), 1.0, "Fully flooded by the middle")
        XCTAssertLessThan(VolcanoLava.back(0.5), 0.2, "Back edge has barely started to rise")
        XCTAssertGreaterThan(VolcanoLava.back(1.0), 1.0, "Page is clear at the end")
        var lastFront = -1.0
        var lastBack = -1.0
        for progress in steps {
            let front = VolcanoLava.front(progress)
            let back = VolcanoLava.back(progress)
            XCTAssertGreaterThanOrEqual(front, lastFront)
            XCTAssertGreaterThanOrEqual(back, lastBack)
            lastFront = front
            lastBack = back
        }
    }

    func testLavaEdgeStaysWithinItsAmplitude() {
        for step in 0...40 {
            for progress in steps {
                let wave = VolcanoLava.edgeWave(x: Double(step) / 40, progress: progress, seed: 0.4)
                XCTAssertLessThanOrEqual(abs(wave), VolcanoLava.edgeAmplitude + 0.0001)
            }
        }
    }

    func testSparksAreDeterministicAndLiveBriefly() {
        XCTAssertEqual(VolcanoLava.sparks.count, VolcanoLava.sparkCount)
        XCTAssertEqual(VolcanoLava.sparks, VolcanoLava.sparks)
        for spark in VolcanoLava.sparks {
            XCTAssertTrue((0...1).contains(spark.x))
            XCTAssertLessThan(spark.spawn + spark.life, 1.0, "Every spark burns out before the end")
            XCTAssertNil(VolcanoLava.state(of: spark, progress: spark.spawn - 0.01))
            XCTAssertNil(VolcanoLava.state(of: spark, progress: spark.spawn + spark.life + 0.01))
            if let start = VolcanoLava.state(of: spark, progress: spark.spawn) {
                XCTAssertEqual(start.alpha, 1, accuracy: 0.001)
            } else {
                XCTFail("A spark shows at its spawn time")
            }
            if let mid = VolcanoLava.state(of: spark, progress: spark.spawn + spark.life * 0.5) {
                XCTAssertTrue((0...1).contains(mid.alpha))
            } else {
                XCTFail("A spark shows mid life")
            }
        }
    }

    func testSparksRiseAwayFromTheLava() {
        let spark = VolcanoLava.sparks[10]
        guard let early = VolcanoLava.state(of: spark, progress: spark.spawn + spark.life * 0.2),
              let late = VolcanoLava.state(of: spark, progress: spark.spawn + spark.life * 0.9) else {
            return XCTFail("Spark should be alive")
        }
        XCTAssertLessThan(late.y, early.y, "y runs from the top, so smaller is higher")
        XCTAssertLessThan(late.alpha, early.alpha)
    }

    func testEmbersFloatUpAndStayOnScreenSideways() {
        XCTAssertEqual(VolcanoLava.embers.count, VolcanoLava.emberCount)
        XCTAssertEqual(VolcanoLava.emberAlpha(0), 0, accuracy: 0.001)
        XCTAssertEqual(VolcanoLava.emberAlpha(1), 0, accuracy: 0.001)
        XCTAssertEqual(VolcanoLava.emberAlpha(0.5), 1, accuracy: 0.001)
        for ember in VolcanoLava.embers {
            let start = VolcanoLava.position(of: ember, progress: 0)
            let end = VolcanoLava.position(of: ember, progress: 1)
            XCTAssertLessThan(end.y, start.y)
            XCTAssertTrue((-0.1...1.1).contains(start.x))
            XCTAssertTrue((-0.1...1.1).contains(end.x))
        }
    }

    // MARK: Deep Ocean

    func testWaveRollsAcrossAndPullsBack() {
        XCTAssertEqual(OceanWave.reach(0), 0, accuracy: 0.001)
        XCTAssertGreaterThan(OceanWave.reach(0.5), 1.1, "The water covers the whole screen")
        XCTAssertEqual(OceanWave.reach(0.55), OceanWave.reach(0.5), accuracy: 0.001, "It holds for a beat")
        XCTAssertEqual(OceanWave.reach(1.0), 0, accuracy: 0.001, "It pulls all the way back")
        var peak = 0.0
        var peakProgress = 0.0
        for progress in steps {
            let reach = OceanWave.reach(progress)
            if reach > peak { peak = reach; peakProgress = progress }
        }
        XCTAssertTrue((0.4...0.6).contains(peakProgress))
        var last = -1.0
        for progress in steps where progress <= 0.5 {
            XCTAssertGreaterThanOrEqual(OceanWave.reach(progress), last)
            last = OceanWave.reach(progress)
        }
        last = 9.0
        for progress in steps where progress >= 0.58 {
            XCTAssertLessThanOrEqual(OceanWave.reach(progress), last)
            last = OceanWave.reach(progress)
        }
    }

    func testWaveEdgeAndFoamStayInRange() {
        for step in 0...40 {
            for progress in steps {
                XCTAssertLessThanOrEqual(abs(OceanWave.edgeSwell(y: Double(step) / 40, progress: progress)), OceanWave.edgeAmplitude + 0.0001)
            }
        }
        for progress in steps {
            XCTAssertTrue((0...1).contains(OceanWave.foam(progress)))
            XCTAssertTrue((0...1).contains(OceanWave.depth(progress)))
        }
        XCTAssertEqual(OceanWave.depth(0), 0, accuracy: 0.001)
        XCTAssertGreaterThan(OceanWave.depth(0.5), 0.9)
    }

    func testBubblesAndRays() {
        XCTAssertEqual(OceanWave.bubbles.count, OceanWave.bubbleCount)
        XCTAssertEqual(OceanWave.bubbles, OceanWave.bubbles)
        for bubble in OceanWave.bubbles {
            XCTAssertLessThan(OceanWave.position(of: bubble, progress: 1).y, OceanWave.position(of: bubble, progress: 0).y)
            XCTAssertGreaterThan(bubble.radius, 0)
        }
        XCTAssertEqual(OceanWave.rays.count, OceanWave.rayCount)
        for ray in OceanWave.rays {
            XCTAssertTrue((0...1).contains(ray.x))
            XCTAssertTrue((0.05...0.13).contains(ray.width))
            XCTAssertTrue((0...0.3).contains(ray.alpha))
            XCTAssertLessThanOrEqual(abs(OceanWave.raySway(ray, progress: 0.37)), 0.02 + 0.0001)
        }
    }

    // MARK: Retro Arcade

    func testDissolveRowsKeepBlocksSquare() {
        XCTAssertEqual(ArcadeDissolve.rows(width: 390, height: 844), 26)
        XCTAssertEqual(ArcadeDissolve.rows(width: 120, height: 120), ArcadeDissolve.columns)
        XCTAssertEqual(ArcadeDissolve.rows(width: 0, height: 100), 1)
    }

    func testBlockNumbersAreStableAndSpread() {
        XCTAssertEqual(ArcadeDissolve.threshold(col: 3, row: 7), ArcadeDissolve.threshold(col: 3, row: 7))
        var values: [Double] = []
        for row in 0..<30 {
            for col in 0..<ArcadeDissolve.columns {
                let value = ArcadeDissolve.threshold(col: col, row: row)
                XCTAssertTrue((0..<1).contains(value))
                XCTAssertTrue((0..<3).contains(ArcadeDissolve.colorIndex(col: col, row: row)))
                values.append(value)
            }
        }
        let average = values.reduce(0, +) / Double(values.count)
        XCTAssertTrue((0.4...0.6).contains(average), "Blocks do not dissolve in one clump")
        XCTAssertGreaterThan(Set(values).count, values.count / 2)
    }

    func testDissolveCoversEverythingInTheMiddleAndNothingAtTheEnds() {
        XCTAssertEqual(ArcadeDissolve.cover(0), 0, accuracy: 0.001)
        XCTAssertEqual(ArcadeDissolve.cover(1), 0, accuracy: 0.001)
        XCTAssertGreaterThan(ArcadeDissolve.cover(0.5), 1.0)
        for row in 0..<30 {
            for col in 0..<ArcadeDissolve.columns {
                XCTAssertTrue(ArcadeDissolve.isOn(col: col, row: row, progress: 0.5))
                XCTAssertFalse(ArcadeDissolve.isOn(col: col, row: row, progress: 0))
                XCTAssertFalse(ArcadeDissolve.isOn(col: col, row: row, progress: 1))
            }
        }
        var onAt = 0
        var onLater = 0
        for row in 0..<30 {
            for col in 0..<ArcadeDissolve.columns {
                if ArcadeDissolve.isOn(col: col, row: row, progress: 0.15) { onAt += 1 }
                if ArcadeDissolve.isOn(col: col, row: row, progress: 0.3) { onLater += 1 }
            }
        }
        XCTAssertGreaterThan(onLater, onAt, "More blocks turn on as it goes")
    }

    func testScanlinesBarAndStars() {
        XCTAssertLessThan(ArcadeDissolve.scanBar(0), 0)
        XCTAssertGreaterThan(ArcadeDissolve.scanBar(1), 1)
        for progress in steps {
            XCTAssertTrue((0...1).contains(ArcadeDissolve.scanlineAlpha(progress)))
            XCTAssertTrue((0...1).contains(ArcadeDissolve.starAlpha(progress)))
        }
        XCTAssertGreaterThan(ArcadeDissolve.scanlineAlpha(0.5), ArcadeDissolve.scanlineAlpha(0))
        XCTAssertEqual(ArcadeDissolve.scanlineSpacing, 3)
        XCTAssertEqual(ArcadeDissolve.stars.count, ArcadeDissolve.starCount)
        XCTAssertEqual(Set(ArcadeDissolve.stars.map(\.color)), [0, 1, 2], "Pink, blue, and yellow")
        for star in ArcadeDissolve.stars {
            XCTAssertTrue((1...2).contains(star.pixels))
            XCTAssertTrue([0.25, 1.0].contains(ArcadeDissolve.twinkle(star, progress: 0.4)))
        }
    }
}
