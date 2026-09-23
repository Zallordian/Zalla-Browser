import XCTest
@testable import Zalla

final class HistoryListHelperTests: XCTestCase {
    func testLimitCapsAndNumbersFromOne() {
        let urls = (0..<8).map { i in
            (title: "Page \(i)", url: URL(string: "https://example.com/\(i)")!)
        }
        let items = HistoryListHelper.limited(urls, limit: 5)
        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items.map(\.id), [1, 2, 3, 4, 5])
        XCTAssertEqual(items.first?.title, "Page 0")
        XCTAssertEqual(items.first?.host, "example.com")
    }

    func testEmptyTitleFallsBackToHost() {
        let items = HistoryListHelper.limited([
            (title: "", url: URL(string: "https://privacy.test/path")!)
        ], limit: 5)
        XCTAssertEqual(items.first?.title, "privacy.test")
        XCTAssertEqual(items.first?.host, "privacy.test")
    }

    func testZeroLimitReturnsEmpty() {
        let items = HistoryListHelper.limited([
            (title: "A", url: URL(string: "https://a.test")!)
        ], limit: 0)
        XCTAssertTrue(items.isEmpty)
    }
}
