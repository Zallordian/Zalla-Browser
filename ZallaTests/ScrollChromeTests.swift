import XCTest
@testable import Zalla

final class ScrollChromeTests: XCTestCase {
    private func scroll(_ offsets: [CGFloat], maxOffset: CGFloat = 2000, from start: ScrollChrome.Tracker = ScrollChrome.Tracker()) -> ScrollChrome.Tracker {
        var tracker = start
        for offset in offsets {
            tracker = ScrollChrome.next(tracker, offset: offset, maxOffset: maxOffset)
        }
        return tracker
    }

    func testSettingsDefaultOn() {
        XCTAssertEqual(ScrollChrome.collapseKey, "collapseToolbarOnScroll")
        XCTAssertEqual(ScrollChrome.underStatusBarKey, "pageUnderStatusBar")
        XCTAssertTrue(ScrollChrome.collapseDefault)
        XCTAssertTrue(ScrollChrome.underStatusBarDefault)
    }

    func testScrollingDownPastTheThresholdCollapses() {
        XCTAssertTrue(scroll([0, 40, 80, 120]).collapsed)
    }

    func testSmallJitterDoesNothing() {
        let collapsed = scroll([0, 100, 200])
        XCTAssertTrue(collapsed.collapsed)
        XCTAssertTrue(scroll([195, 205, 198, 203], from: collapsed).collapsed, "A few points back and forth keep the bar collapsed")
        let expanded = scroll([0, 100, 200, 150, 100])
        XCTAssertFalse(expanded.collapsed)
        XCTAssertFalse(scroll([105, 112, 108], from: expanded).collapsed)
    }

    func testScrollingUpExpands() {
        XCTAssertFalse(scroll([0, 100, 300, 260, 240]).collapsed)
    }

    func testTopAndBottomShowTheFullBar() {
        XCTAssertFalse(scroll([0, 100, 300, 5]).collapsed)
        XCTAssertFalse(scroll([0, 100, 300, 1000, 1995], maxOffset: 2000).collapsed)
    }

    func testShortPagesNeverCollapse() {
        XCTAssertFalse(scroll([0, 40, 80], maxOffset: 90).collapsed)
    }

    func testCollapseOnlyForABottomClassicOrCompactBar() {
        XCTAssertTrue(ScrollChrome.canCollapse(enabled: true, bottomBar: true, quickAction: false, hasPage: true, editing: false))
        XCTAssertFalse(ScrollChrome.canCollapse(enabled: false, bottomBar: true, quickAction: false, hasPage: true, editing: false))
        XCTAssertFalse(ScrollChrome.canCollapse(enabled: true, bottomBar: false, quickAction: false, hasPage: true, editing: false))
        XCTAssertFalse(ScrollChrome.canCollapse(enabled: true, bottomBar: true, quickAction: true, hasPage: true, editing: false))
        XCTAssertFalse(ScrollChrome.canCollapse(enabled: true, bottomBar: true, quickAction: false, hasPage: false, editing: false))
        XCTAssertFalse(ScrollChrome.canCollapse(enabled: true, bottomBar: true, quickAction: false, hasPage: true, editing: true))
    }

    func testPageUnderStatusBarNeedsEverything() {
        XCTAssertTrue(ScrollChrome.pageUnderStatusBar(enabled: true, immersive: true, bottomBar: true, supported: true))
        XCTAssertFalse(ScrollChrome.pageUnderStatusBar(enabled: true, immersive: true, bottomBar: false, supported: true))
        XCTAssertFalse(ScrollChrome.pageUnderStatusBar(enabled: true, immersive: true, bottomBar: true, supported: false))
        XCTAssertFalse(ScrollChrome.pageUnderStatusBar(enabled: true, immersive: false, bottomBar: true, supported: true))
        XCTAssertFalse(ScrollChrome.pageUnderStatusBar(enabled: false, immersive: true, bottomBar: true, supported: true))
    }

    func testClearPlanLetsThePageUnderTheStatusBar() {
        let plan = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .black, appearance: "System", underStatusBar: true)
        XCTAssertEqual(plan.fill, .clear(.black))
        XCTAssertEqual(plan.schemeOverride, .dark)
        XCTAssertFalse(plan.startsBelowStatusBar)
        XCTAssertEqual(plan.fill.pageColor, .black)
        let unknown = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: nil, appearance: "System", underStatusBar: true)
        XCTAssertEqual(unknown.fill, .clear(nil))
        let clash = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .white, appearance: "Dark", underStatusBar: true)
        XCTAssertEqual(clash, PageColor.StatusBarPlan(fill: .clear(nil), schemeOverride: nil))
        let newTab = PageColor.plan(immersive: true, matchPage: true, hasPage: false, sample: .white, appearance: "System", underStatusBar: true)
        XCTAssertEqual(newTab.fill, .none)
    }
}
