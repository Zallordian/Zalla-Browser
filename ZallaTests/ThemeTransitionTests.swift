import XCTest
@testable import Zalla

final class ThemeTransitionTests: XCTestCase {
    private func plan(unlocked: Bool = true, enabled: Bool = true, reduce: Bool = false,
                      speed: ThemeTransitionSpeed = .normal, kind: ThemeTransitionKind = .jungle) -> ThemeTransitionPlan? {
        ThemeTransitionPlan.make(kind: kind, unlocked: unlocked, enabled: enabled, reduceMotion: reduce, speed: speed)
    }

    func testGatingStaysTheSameAsBefore() {
        XCTAssertNotNil(plan())
        XCTAssertNil(plan(unlocked: false), "Theme packs are part of Zalla Unlock")
        XCTAssertNil(plan(enabled: false))
    }

    func testNormalIsAboutOneSecondAndSpeedsScaleIt() {
        XCTAssertEqual(plan()?.duration ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(plan(speed: .slow)?.duration ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(plan(speed: .fast)?.duration ?? 0, 0.65, accuracy: 0.001)
        XCTAssertEqual(plan()?.style, .full)
    }

    func testReduceMotionBecomesAQuickFade() {
        let reduced = plan(reduce: true)
        XCTAssertEqual(reduced?.style, .fade)
        XCTAssertLessThan(reduced?.duration ?? 9, 0.6)
        XCTAssertNil(plan(enabled: false, reduce: true), "Off stays off")
        XCTAssertEqual(plan(kind: .space)?.kind, .space)
    }

    func testSpeedStorage() {
        XCTAssertEqual(ThemeTransitionSpeed(stored: nil), .normal)
        XCTAssertEqual(ThemeTransitionSpeed(stored: "Fast"), .fast)
        XCTAssertEqual(ThemeTransitionSpeed(stored: "warp"), .normal)
        XCTAssertEqual(ThemeTransitionSpeed.allCases.map(\.rawValue), ["Slow", "Normal", "Fast"])
    }

    func testLeavesAreDeterministicAndStayInTheLayer() {
        for layer in 0..<JungleLeaves.layerCount {
            for mirrored in [false, true] {
                let leaves = JungleLeaves.leaves(layer: layer, mirrored: mirrored)
                XCTAssertEqual(leaves.count, JungleLeaves.leafCounts[layer])
                XCTAssertEqual(leaves, JungleLeaves.leaves(layer: layer, mirrored: mirrored))
                for leaf in leaves {
                    XCTAssertLessThanOrEqual(leaf.tipX, 1.0)
                    XCTAssertTrue((0...1).contains(leaf.rootY))
                    XCTAssertGreaterThan(leaf.length, 0.1)
                    XCTAssertGreaterThan(leaf.width, 0.02)
                }
                XCTAssertEqual(leaves.map(\.rootY), leaves.map(\.rootY).sorted(), "Rows run top to bottom")
            }
        }
        XCTAssertNotEqual(JungleLeaves.leaves(layer: 0, mirrored: false), JungleLeaves.leaves(layer: 0, mirrored: true))
    }

    func testCurtainLayersSlideInBackFirstAndOutBackLast() {
        let n = JungleLeaves.layerCount
        for layer in 0..<n {
            XCTAssertEqual(TransitionCurve.curtain(0, layer: layer, of: n), 0, accuracy: 0.0001)
            XCTAssertEqual(TransitionCurve.curtain(1, layer: layer, of: n), 0, accuracy: 0.0001)
            XCTAssertEqual(TransitionCurve.curtain(0.52, layer: layer, of: n), 1, accuracy: 0.0001, "Every layer covers the screen at the middle")
        }
        XCTAssertGreaterThan(TransitionCurve.curtain(0.2, layer: 0, of: n), TransitionCurve.curtain(0.2, layer: n - 1, of: n))
        XCTAssertGreaterThan(TransitionCurve.curtain(0.8, layer: 0, of: n), TransitionCurve.curtain(0.8, layer: n - 1, of: n))
    }

    func testCurtainMovesOneWayOnEachHalf() {
        let n = JungleLeaves.layerCount
        for layer in 0..<n {
            var last = 0.0
            for step in 0...50 {
                let value = TransitionCurve.curtain(Double(step) / 100, layer: layer, of: n)
                XCTAssertGreaterThanOrEqual(value, last - 0.0001)
                last = value
            }
            for step in 50...100 {
                let value = TransitionCurve.curtain(Double(step) / 100, layer: layer, of: n)
                XCTAssertLessThanOrEqual(value, last + 0.0001)
                last = value
            }
        }
    }

    func testReduceMotionFadeTintsAndClears() {
        XCTAssertEqual(TransitionCurve.fadeOpacity(0), 0, accuracy: 0.0001)
        XCTAssertEqual(TransitionCurve.fadeOpacity(0.5), 0.85, accuracy: 0.0001)
        XCTAssertEqual(TransitionCurve.fadeOpacity(1), 0, accuracy: 0.0001)
        XCTAssertEqual(TransitionCurve.fadeOpacity(9), 0, accuracy: 0.0001, "Out of range times clamp")
    }

    func testLeavesAreVariedAndSwayStaysGentle() {
        for layer in 0..<JungleLeaves.layerCount {
            let leaves = JungleLeaves.leaves(layer: layer, mirrored: false)
            XCTAssertGreaterThan(Set(leaves.map(\.curve)).count, leaves.count / 2, "Leaves bow differently")
            for leaf in leaves {
                XCTAssertTrue((-1...1).contains(leaf.curve))
                XCTAssertTrue((0.5...2).contains(leaf.asymmetry))
                XCTAssertTrue((0...1).contains(leaf.tone))
                for step in 0...20 {
                    let sway = JungleLeaves.sway(leaf, progress: Double(step) / 20, layer: layer)
                    XCTAssertLessThan(abs(sway), 0.1)
                }
            }
        }
    }

    func testRocketAcceleratesAndTheGlowLiftsAfterIt() {
        XCTAssertEqual(SpaceFlight.thrust(0), 0, accuracy: 0.0001)
        XCTAssertEqual(SpaceFlight.thrust(SpaceFlight.flightEnd), 1, accuracy: 0.0001)
        XCTAssertEqual(SpaceFlight.thrust(1), 1, accuracy: 0.0001)
        var last = -1.0
        var lastStep = 0.0
        for step in 0...74 {
            let value = SpaceFlight.thrust(Double(step) / 100)
            XCTAssertGreaterThanOrEqual(value, last)
            if step > 1 && step < 74 {
                XCTAssertGreaterThanOrEqual(value - last, lastStep - 0.0001, "It keeps speeding up")
            }
            lastStep = value - max(last, 0)
            last = value
        }
        XCTAssertEqual(SpaceFlight.lift(0.3), 0, accuracy: 0.0001)
        XCTAssertEqual(SpaceFlight.lift(SpaceFlight.liftStart), 0, accuracy: 0.0001)
        XCTAssertEqual(SpaceFlight.lift(1), 1, accuracy: 0.0001)
        XCTAssertLessThan(SpaceFlight.liftStart, SpaceFlight.flightEnd)
    }

    func testSmokeAndStreaksAreDeterministicAndInRange() {
        XCTAssertEqual(SpaceFlight.puffs.count, 14)
        XCTAssertEqual(SpaceFlight.puffs, SpaceFlight.puffs.sorted { $0.spawn < $1.spawn }, "Puffs leave the engine in order")
        for puff in SpaceFlight.puffs {
            XCTAssertGreaterThan(puff.spawn, 0)
            XCTAssertLessThanOrEqual(puff.spawn + SpaceFlight.puffLife, 1)
            XCTAssertTrue((0.03...0.08).contains(puff.radius))
        }
        for streak in SpaceFlight.streaks {
            XCTAssertTrue((0...1).contains(streak.x))
            XCTAssertTrue((0...1).contains(streak.y))
            XCTAssertLessThan(streak.alpha, 0.5)
        }
    }

    func testBurnPlanRules() {
        XCTAssertEqual(BurnEffectPlan.make(reduceMotion: false).style, .fire)
        XCTAssertGreaterThanOrEqual(BurnEffectPlan.make(reduceMotion: false).duration, 2.0)
        XCTAssertLessThanOrEqual(BurnEffectPlan.make(reduceMotion: false).duration, 2.5)
        XCTAssertEqual(BurnEffectPlan.make(reduceMotion: true).style, .fade)
        XCTAssertLessThan(BurnEffectPlan.make(reduceMotion: true).duration, 0.5)
    }

    func testBurnEffectCanBeSwitchedOff() {
        XCTAssertEqual(BurnEffectPlan.make(reduceMotion: false, animated: false).style, .fade)
        XCTAssertEqual(BurnEffectPlan.make(reduceMotion: true, animated: true).style, .fade)
        let defaults = UserDefaults(suiteName: "ThemeTransitionTests.burn")!
        defaults.removePersistentDomain(forName: "ThemeTransitionTests.burn")
        XCTAssertTrue(BurnEffectPlan.animationEnabled(in: defaults), "On by default")
        defaults.set(false, forKey: BurnEffectPlan.animationKey)
        XCTAssertFalse(BurnEffectPlan.animationEnabled(in: defaults))
    }
}
