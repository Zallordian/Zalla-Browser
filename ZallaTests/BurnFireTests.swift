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

    func testNoEmDashesInTheLabels() {
        XCTAssertFalse("Clearing browsing data...".contains("\u{2014}"))
    }
}
