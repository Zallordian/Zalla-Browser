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

final class BookmarkImportTests: XCTestCase {
    func testSingleQuotesEntitiesAndMultilineTitles() {
        let html = "<DL><DT><A ADD_DATE=\"1\" HREF='https://example.com/?a=1&amp;b=2'>Tom &amp;\n Jerry</A></DL>"
        let pages = BookmarkHTML.parse(html)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].url.absoluteString, "https://example.com/?a=1&b=2")
        XCTAssertEqual(pages[0].title, "Tom & Jerry")
    }

    func testTextDecodingFallsBack() {
        XCTAssertEqual(BookmarkHTML.text(from: Data("hi".utf8)), "hi")
        XCTAssertNotNil(BookmarkHTML.text(from: Data([0xE9, 0x41])))
    }
}
