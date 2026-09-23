import XCTest
@testable import Zalla

final class ToolbarStyleTests: XCTestCase {
    func testDefaultRawValues() {
        XCTAssertEqual(ToolbarStyle.classic.rawValue, "Classic")
        XCTAssertEqual(ToolbarStyle.compact.rawValue, "Compact")
        XCTAssertEqual(ToolbarStyle.storageKey, "toolbarStyle")
    }

    func testCompactPillTitleForNewTab() {
        XCTAssertEqual(
            CompactAddressChrome.pillTitle(hasPage: false, pageTitle: "", isReaderActive: false),
            "Search or enter a website"
        )
    }

    func testCompactPillTitleForLoadedPage() {
        XCTAssertEqual(
            CompactAddressChrome.pillTitle(hasPage: true, pageTitle: "Example", isReaderActive: false),
            "Example"
        )
        XCTAssertEqual(
            CompactAddressChrome.pillTitle(hasPage: true, pageTitle: "Reader", isReaderActive: true),
            "Reader"
        )
    }

    func testCompactHostSubtitle() {
        let url = URL(string: "https://example.com/path")
        XCTAssertEqual(CompactAddressChrome.hostSubtitle(url: url, hasPage: true), "example.com")
        XCTAssertNil(CompactAddressChrome.hostSubtitle(url: url, hasPage: false))
        XCTAssertNil(CompactAddressChrome.hostSubtitle(url: nil, hasPage: true))
    }

    func testCompactEditingPrefill() {
        let url = URL(string: "https://example.com/path?q=1")
        XCTAssertEqual(CompactAddressChrome.editingPrefill(url: url), "https://example.com/path?q=1")
        XCTAssertEqual(CompactAddressChrome.editingPrefill(url: nil), "")
    }
}
