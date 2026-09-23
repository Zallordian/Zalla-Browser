import XCTest
@testable import Zalla

final class BookmarkHTMLTests: XCTestCase {
    func testParseNetscapeBookmarks() {
        let html = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <DL><p>
            <DT><A HREF="https://example.com/one">Example One</A>
            <DT><A HREF="https://example.org/two">Example Two</A>
            <DT><A HREF="javascript:alert(1)">Bad</A>
        </DL><p>
        """
        let pages = BookmarkHTML.parse(html)
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].title, "Example One")
        XCTAssertEqual(pages[0].url.absoluteString, "https://example.com/one")
        XCTAssertEqual(pages[1].url.host, "example.org")
    }

    func testExportRoundTripContainsLinks() {
        let bookmarks = [
            SavedPage(title: "Zalla", url: URL(string: "https://zalla.example")!),
            SavedPage(title: "Docs", url: URL(string: "https://docs.example/path")!)
        ]
        let html = BookmarkHTML.exportHTML(bookmarks: bookmarks)
        XCTAssertTrue(html.contains("NETSCAPE-Bookmark-file-1"))
        let parsed = BookmarkHTML.parse(html)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed.map(\.url), bookmarks.map(\.url))
    }
}
