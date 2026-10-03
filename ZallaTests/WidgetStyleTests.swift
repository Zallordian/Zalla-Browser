import XCTest
@testable import Zalla

final class WidgetStyleTests: XCTestCase {
    func testLooksHaveStableKeysAndTitles() {
        XCTAssertEqual(WidgetLookKey.allCases.map(\.rawValue), ["gradient", "midnight", "aurora", "glass", "paper"])
        XCTAssertEqual(WidgetLookKey.defaultLook, .gradient)
        for look in WidgetLookKey.allCases {
            XCTAssertFalse(look.title.isEmpty)
            XCTAssertFalse(look.title.contains("\u{2014}"))
            XCTAssertFalse(look.title.contains("\u{2013}"))
        }
    }

    func testTileInitialUsesTheFirstLetterOrDigit() {
        XCTAssertEqual(WidgetTileRules.initial(of: "news"), "N")
        XCTAssertEqual(WidgetTileRules.initial(of: "www.example.com"), "E")
        XCTAssertEqual(WidgetTileRules.initial(of: "  7 days"), "7")
        XCTAssertEqual(WidgetTileRules.initial(of: "!!!"), "Z")
        XCTAssertEqual(WidgetTileRules.initial(of: ""), "Z")
    }

    func testOnlyThePlainGlobeShowsALetter() {
        XCTAssertTrue(WidgetTileRules.showsInitial(symbolName: "globe"))
        XCTAssertTrue(WidgetTileRules.showsInitial(symbolName: ""))
        XCTAssertFalse(WidgetTileRules.showsInitial(symbolName: "book"))
    }

    func testTileColorIsFixedAndInRange() {
        // These values come from the same arithmetic in the widget, so a tile keeps its color between reloads.
        XCTAssertEqual(WidgetTileRules.colorIndex(for: "a", count: 8), 6)
        XCTAssertEqual(WidgetTileRules.colorIndex(for: "News", count: 8), 2)
        XCTAssertEqual(WidgetTileRules.colorIndex(for: "news", count: 8), 2)
        XCTAssertEqual(WidgetTileRules.colorIndex(for: "Mail", count: 8), 0)
        XCTAssertEqual(WidgetTileRules.colorIndex(for: "anything", count: 0), 0)
        for title in ["x", "Zalla", "Weather", "a much longer title than usual"] {
            let index = WidgetTileRules.colorIndex(for: title, count: 8)
            XCTAssertTrue((0..<8).contains(index))
        }
    }

    func testRingSegmentsCoverTheCircleAndSkipZeros() {
        XCTAssertEqual(WidgetRingRules.segments([0, 0, 0]), [])
        XCTAssertEqual(WidgetRingRules.segments([]), [])
        let single = WidgetRingRules.segments([0, 5, 0])
        XCTAssertEqual(single, [WidgetRingRules.Segment(index: 1, start: 0, end: 1)])
        let three = WidgetRingRules.segments([2, 1, 1], gap: 0)
        XCTAssertEqual(three.map(\.index), [0, 1, 2])
        XCTAssertEqual(three[0].start, 0, accuracy: 0.0001)
        XCTAssertEqual(three[0].end, 0.5, accuracy: 0.0001)
        XCTAssertEqual(three[2].end, 1, accuracy: 0.0001)
        let gapped = WidgetRingRules.segments([1, 1])
        XCTAssertGreaterThan(gapped[0].start, 0)
        XCTAssertLessThan(gapped[0].end, gapped[1].start)
        XCTAssertLessThan(gapped[1].end, 1)
    }
}
