import XCTest
@testable import Zalla

/// Redesign phase 2: the shared Layout picker maps cleanly onto the three stored settings.
final class LayoutPresetTests: XCTestCase {
    func testEachPresetReadsBackAsItself() {
        for preset in LayoutPreset.allCases {
            for placement in AddressBarPlacement.allCases {
                let stored = preset.settings(placement: placement)
                let read = LayoutPreset.current(layout: stored.layout, style: stored.style, placement: stored.placement)
                XCTAssertEqual(read, preset, "\(preset) at \(placement) reads back as \(read)")
            }
        }
    }

    func testSafariStyleIsBottomOnly() {
        XCTAssertFalse(LayoutPreset.safari.supportsTopPlacement)
        XCTAssertEqual(LayoutPreset.safari.settings(placement: .top).placement, .bottom)
        XCTAssertEqual(LayoutPreset.compact.settings(placement: .top).placement, .top)
    }

    func testCurrentMatchesWhatTheBrowserDraws() {
        // Fresh install: Safari style Bar Layout, Classic style, bottom.
        XCTAssertEqual(LayoutPreset.current(layout: .defaultLayout, style: .classic, placement: .bottom), .safari)
        // Safari style never replaces the Quick Action bar.
        XCTAssertEqual(LayoutPreset.current(layout: .safari, style: .quickAction, placement: .bottom), .quickAction)
        // With the bar on top the chosen style is drawn.
        XCTAssertEqual(LayoutPreset.current(layout: .safari, style: .compact, placement: .top), .compact)
        XCTAssertEqual(LayoutPreset.current(layout: .classic, style: .classic, placement: .bottom), .classic)
    }

    func testCopyIsPlain() {
        for preset in LayoutPreset.allCases {
            for line in [preset.title, preset.summary] {
                XCTAssertFalse(line.contains("\u{2014}"), "Em dash in: \(line)")
                XCTAssertFalse(line.contains("\u{2013}"), "En dash in: \(line)")
                XCTAssertFalse(line.isEmpty)
            }
        }
    }
}
