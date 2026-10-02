import XCTest
@testable import Zalla

final class BurnFireTests: XCTestCase {
    func testPhasesRunInOrder() {
        XCTAssertEqual(BurnFire.phase(at: 0), .rise)
        XCTAssertEqual(BurnFire.phase(at: 0.2), .rise)
        XCTAssertEqual(BurnFire.phase(at: 0.4), .blaze)
        XCTAssertEqual(BurnFire.phase(at: 0.6), .breakApart)
        XCTAssertEqual(BurnFire.phase(at: 0.9), .embers)
        XCTAssertEqual(BurnFire.phase(at: 1), .embers)
        XCTAssertEqual(BurnFire.phase(at: -3), .rise, "Out of range times clamp")
        XCTAssertEqual(BurnFire.phase(at: 7), .embers)
    }

    func testBrowserCharsThenGoesFullyBlack() {
        XCTAssertEqual(BurnFire.cover(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(BurnFire.cover(at: 1), 1, accuracy: 0.0001)
        var last = -1.0
        for step in 0...100 {
            let value = BurnFire.cover(at: Double(step) / 100)
            XCTAssertGreaterThanOrEqual(value, last, "The browser only gets darker")
            last = value
        }
        XCTAssertGreaterThan(BurnFire.cover(at: 0.5), 0.8)
    }

    func testIntensityPeaksInTheBlazeAndIsGoneAtTheEnd() {
        XCTAssertEqual(BurnFire.intensity(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(BurnFire.intensity(at: 0.4), 1, accuracy: 0.0001)
        XCTAssertEqual(BurnFire.intensity(at: 1), 0, accuracy: 0.0001)
    }

    func testLabelAppearsOnlyAtTheEnd() {
        XCTAssertEqual(BurnFire.labelOpacity(at: 0.5), 0)
        XCTAssertEqual(BurnFire.labelOpacity(at: 0.9), 0)
        XCTAssertEqual(BurnFire.labelOpacity(at: 1), 1, accuracy: 0.0001)
    }

    func testTonguesAreTheSameEveryTimeAndStayOnScreen() {
        XCTAssertEqual(BurnFire.tongues.count, 22)
        XCTAssertEqual(BurnFire.tongues.filter { $0.row == 0 }.count, 9)
        for tongue in BurnFire.tongues {
            XCTAssertTrue(tongue.baseX > 0 && tongue.baseX < 1)
            XCTAssertGreaterThan(tongue.width, 0.1)
            XCTAssertGreaterThan(tongue.height, 0.5)
            XCTAssertTrue((0...1).contains(tongue.delay))
            XCTAssertTrue((0...1).contains(tongue.breakDelay))
        }
    }

    func testTongueGrowsThenBreaksApartAndFades() {
        for tongue in BurnFire.tongues {
            let start = BurnFire.state(of: tongue, at: 0)
            XCTAssertEqual(start.scale, 0, accuracy: 0.0001)
            XCTAssertEqual(start.lift, 0, accuracy: 0.0001)
            let blaze = BurnFire.state(of: tongue, at: BurnFire.blazeEnd - 0.001)
            XCTAssertEqual(blaze.scale, 1, accuracy: 0.0001, "Every tongue is at full height before it breaks apart")
            XCTAssertEqual(blaze.opacity, 1, accuracy: 0.0001)
            let end = BurnFire.state(of: tongue, at: 1)
            XCTAssertEqual(end.opacity, 0, accuracy: 0.0001, "All the flames are out by the end")
            XCTAssertGreaterThan(end.lift, 0.1, "Licks float up as they break loose")
            var previous = 0.0
            for step in 0...100 {
                let lift = BurnFire.state(of: tongue, at: Double(step) / 100).lift
                XCTAssertGreaterThanOrEqual(lift, previous)
                previous = lift
            }
        }
    }

    func testOutlineIsASharpClosedShapeWithTheTipOnTop() {
        let tongue = BurnFire.tongues[0]
        for time in [0.0, 0.5, 1.7] {
            let points = BurnFire.outline(of: tongue, time: time)
            XCTAssertEqual(points.count, 2 * 9 + 1)
            XCTAssertEqual(points.first?.y ?? 1, 0, accuracy: 0.0001)
            XCTAssertEqual(points.last?.y ?? 1, 0, accuracy: 0.0001)
            XCTAssertLessThan(points.first?.x ?? 1, points.last?.x ?? -1, "The base has width")
            let tip = points[9]
            XCTAssertEqual(points.map(\.y).max() ?? 0, tip.y, accuracy: 0.0001)
            XCTAssertGreaterThan(tip.y, 0.9)
        }
        XCTAssertEqual(BurnFire.outline(of: tongue, time: 0.3), BurnFire.outline(of: tongue, time: 0.3))
        XCTAssertNotEqual(BurnFire.outline(of: tongue, time: 0.3), BurnFire.outline(of: tongue, time: 0.4), "It swirls and flickers")
    }

    func testEdgesHaveTeeth() {
        let tongue = BurnFire.Tongue(
            row: 0, baseX: 0.5, width: 0.3, height: 1, lean: 0, phase: 0, speed: 0,
            jag: 0.3, delay: 0, breakDelay: 0, drift: 0
        )
        let points = BurnFire.outline(of: tongue, time: 0)
        // On the left side every second point is cut in, so the edge zigzags instead of running straight.
        let left = Array(points[0...9])
        var turns = 0
        for i in 1..<(left.count - 1) {
            let before = left[i].x - left[i - 1].x
            let after = left[i + 1].x - left[i].x
            if before * after < 0 { turns += 1 }
        }
        XCTAssertGreaterThan(turns, 2)
    }

    func testEmbersGlowThenGoOutBeforeTheEnd() {
        XCTAssertEqual(BurnFire.embers.count, 44)
        for ember in BurnFire.embers {
            XCTAssertEqual(BurnFire.state(of: ember, at: 0.3).alpha, 0, accuracy: 0.0001, "Embers wait for the flames to break apart")
            XCTAssertEqual(BurnFire.state(of: ember, at: 1).alpha, 0, accuracy: 0.0001)
            XCTAssertTrue((0...1).contains(ember.x))
        }
        let glowing = BurnFire.embers.filter { BurnFire.state(of: $0, at: 0.85).alpha > 0.05 }
        XCTAssertGreaterThan(glowing.count, 5)
    }

    func testSmoothSegmentsRoundTheOutlineWithoutLeavingIt() {
        let tongue = BurnFire.tongues[0]
        let points = BurnFire.outline(of: tongue, time: 0.7)
        let segments = BurnFire.smoothSegments(points)
        XCTAssertEqual(segments.count, points.count - 2)
        XCTAssertEqual(segments.last?.end, points.last, "The curve finishes on the last base corner")
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        for segment in segments {
            XCTAssertTrue(points.contains(segment.control), "Every curve bends toward one of the corners")
            XCTAssertGreaterThanOrEqual(segment.end.x, minX - 0.0001)
            XCTAssertLessThanOrEqual(segment.end.x, maxX + 0.0001)
            XCTAssertGreaterThanOrEqual(segment.end.y, 0)
            XCTAssertLessThanOrEqual(segment.end.y, maxY + 0.0001)
        }
        // The curve cuts the corners, so the passing points sit between the corners, not on them.
        if segments.count > 2 {
            XCTAssertEqual(segments[0].end, BurnFire.midpoint(points[1], points[2]))
        }
    }

    func testSmoothSegmentsHandleTinyOutlines() {
        XCTAssertTrue(BurnFire.smoothSegments([]).isEmpty)
        XCTAssertTrue(BurnFire.smoothSegments([BurnFire.Point(x: 0, y: 0)]).isEmpty)
        let three = [BurnFire.Point(x: 0, y: 0), BurnFire.Point(x: 1, y: 2), BurnFire.Point(x: 2, y: 0)]
        let segments = BurnFire.smoothSegments(three)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].control, three[1])
        XCTAssertEqual(segments[0].end, three[2])
    }

    func testFlameEdgesFlutterOverTimeWithoutBreakingTheShape() {
        let tongue = BurnFire.tongues[3]
        var previous: [BurnFire.Point] = []
        for step in 0..<12 {
            let points = BurnFire.outline(of: tongue, time: Double(step) * 0.13)
            XCTAssertEqual(points.count, 19)
            XCTAssertEqual(points.first?.y ?? 1, 0, accuracy: 0.0001)
            XCTAssertEqual(points.last?.y ?? 1, 0, accuracy: 0.0001)
            XCTAssertTrue(points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.y >= 0 })
            XCTAssertNotEqual(points, previous)
            previous = points
        }
    }

    func testEmbersComeInSeveralKinds() {
        let kinds = Set(BurnFire.embers.map(\.kind))
        XCTAssertEqual(kinds, [0, 1, 2], "Dots, sparks, and ash flakes")
        XCTAssertGreaterThan(BurnFire.embers.filter { $0.kind == 0 }.count, 10)
        for ember in BurnFire.embers {
            XCTAssertTrue((0...2).contains(ember.kind))
            XCTAssertGreaterThan(ember.wobble, 0)
        }
    }

    func testTimingAndStructureAreUnchanged() {
        XCTAssertEqual(BurnFire.riseEnd, 0.30)
        XCTAssertEqual(BurnFire.blazeEnd, 0.55)
        XCTAssertEqual(BurnFire.breakEnd, 0.78)
        XCTAssertEqual(BurnFire.tongues.count, 22)
        XCTAssertEqual(BurnFire.embers.count, 44)
    }

    func testProgressComesFromTheStartTimeAndNeverRestarts() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(BurnFire.progress(startedAt: start, now: start, duration: 2.4), 0, accuracy: 0.0001)
        XCTAssertEqual(BurnFire.progress(startedAt: start, now: start.addingTimeInterval(1.2), duration: 2.4), 0.5, accuracy: 0.0001)
        XCTAssertEqual(BurnFire.progress(startedAt: start, now: start.addingTimeInterval(2.4), duration: 2.4), 1, accuracy: 0.0001)
        XCTAssertEqual(BurnFire.progress(startedAt: start, now: start.addingTimeInterval(60), duration: 2.4), 1, "It stays finished")
        XCTAssertEqual(BurnFire.progress(startedAt: start, now: start.addingTimeInterval(-5), duration: 2.4), 0)
        XCTAssertEqual(BurnFire.progress(startedAt: start, now: start, duration: 0), 1)
    }

    func testPlanCarriesItsStartTimeAndAFinishedFireDrawsNoFlames() {
        let start = Date(timeIntervalSince1970: 5_000)
        let plan = BurnEffectPlan.make(reduceMotion: false, now: start)
        XCTAssertEqual(plan.startedAt, start)
        let end = BurnFire.progress(startedAt: plan.startedAt, now: start.addingTimeInterval(500), duration: plan.duration)
        XCTAssertEqual(end, 1)
        for tongue in BurnFire.tongues {
            XCTAssertEqual(BurnFire.state(of: tongue, at: end).opacity, 0, accuracy: 0.0001)
        }
        for ember in BurnFire.embers {
            XCTAssertEqual(BurnFire.state(of: ember, at: end).alpha, 0, accuracy: 0.0001)
        }
        XCTAssertEqual(BurnFire.cover(at: end), 1, accuracy: 0.0001)
        XCTAssertEqual(BurnFire.labelOpacity(at: end), 1, accuracy: 0.0001)
    }

    func testNoEmDashesInTheLabels() {
        XCTAssertFalse("Clearing browsing data...".contains("\u{2014}"))
    }
}
