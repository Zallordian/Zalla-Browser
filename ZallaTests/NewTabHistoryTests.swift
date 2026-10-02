import XCTest
@testable import Zalla

final class NewTabHistoryTests: XCTestCase {
    private func history(behind: Bool, parked: Bool = false) -> NewTabHistory {
        NewTabHistory(hasNewTabBehind: behind, isParked: parked)
    }

    func testBackFromTheFirstPageGoesToTheNewTabPage() {
        let h = history(behind: true)
        XCTAssertTrue(h.canGoBack(webCanGoBack: false, pageShown: true))
        XCTAssertEqual(h.backStep(webCanGoBack: false, pageShown: true), .showNewTab)
    }

    func testBackInsideWebHistoryStaysWithTheWebView() {
        let h = history(behind: true)
        XCTAssertEqual(h.backStep(webCanGoBack: true, pageShown: true), .web)
    }

    func testTabsThatDidNotStartOnTheNewTabPageHaveNothingBehindTheFirstPage() {
        let h = history(behind: false)
        XCTAssertFalse(h.canGoBack(webCanGoBack: false, pageShown: true))
        XCTAssertNil(h.backStep(webCanGoBack: false, pageShown: true))
        XCTAssertTrue(h.canGoBack(webCanGoBack: true, pageShown: true))
    }

    func testBlankNewTabPageHasNowhereToGoBack() {
        let h = history(behind: true)
        XCTAssertFalse(h.canGoBack(webCanGoBack: false, pageShown: false))
        XCTAssertNil(h.backStep(webCanGoBack: false, pageShown: false))
        XCTAssertFalse(h.canGoForward(webCanGoForward: false))
        XCTAssertNil(h.forwardStep(webCanGoForward: false))
    }

    func testForwardFromTheParkedNewTabPageShowsThePageAgain() {
        let h = history(behind: true, parked: true)
        XCTAssertTrue(h.canGoForward(webCanGoForward: false))
        XCTAssertEqual(h.forwardStep(webCanGoForward: false), .showPage)
        XCTAssertFalse(h.canGoBack(webCanGoBack: true, pageShown: false), "Nothing sits behind the new tab page")
        XCTAssertNil(h.backStep(webCanGoBack: true, pageShown: false))
    }

    func testForwardOnAWebPageUsesTheWebViewList() {
        let h = history(behind: true)
        XCTAssertEqual(h.forwardStep(webCanGoForward: true), .web)
        XCTAssertNil(h.forwardStep(webCanGoForward: false))
    }

    func testBackEntriesEndWithTheNewTabPage() {
        let h = history(behind: true)
        let entries = h.backEntries(web: ["c", "b", "a"], limit: 5, pageShown: true)
        XCTAssertEqual(entries, [.web("c"), .web("b"), .web("a"), .newTab])
    }

    func testBackEntriesFromTheFirstPageIsJustTheNewTabPage() {
        let h = history(behind: true)
        XCTAssertEqual(h.backEntries(web: [String](), limit: 5, pageShown: true), [.newTab])
    }

    func testBackEntriesRespectTheLimit() {
        let h = history(behind: true)
        let entries = h.backEntries(web: ["d", "c", "b", "a"], limit: 3, pageShown: true)
        XCTAssertEqual(entries, [.web("d"), .web("c"), .web("b")])
        XCTAssertTrue(h.backEntries(web: ["a"], limit: 0, pageShown: true).isEmpty)
    }

    func testBackEntriesAreEmptyWhileParked() {
        let h = history(behind: true, parked: true)
        XCTAssertTrue(h.backEntries(web: ["a"], limit: 5, pageShown: false).isEmpty)
    }

    func testForwardEntriesStartWithThePageWhenParked() {
        let h = history(behind: true, parked: true)
        XCTAssertEqual(h.forwardEntries(web: ["b", "c"], limit: 5), [.currentPage, .web("b"), .web("c")])
        XCTAssertEqual(h.forwardEntries(web: ["b", "c"], limit: 2), [.currentPage, .web("b")])
    }

    func testForwardEntriesOnAPageAreTheWebList() {
        let h = history(behind: true)
        XCTAssertEqual(h.forwardEntries(web: ["b"], limit: 5), [.web("b")])
        XCTAssertTrue(h.forwardEntries(web: [String](), limit: 5).isEmpty)
    }
}
