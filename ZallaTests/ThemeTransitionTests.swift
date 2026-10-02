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
