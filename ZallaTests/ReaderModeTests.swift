import XCTest
@testable import Zalla

final class ReaderModeTests: XCTestCase {
    func testParseExtractedJSON() {
        let raw = """
        {"title":"Hello","byline":"Kurt","site":"example.com","paragraphs":[{"tag":"p","text":"Body text here."}]}
        """
        let article = ReaderMode.parseExtractedJSON(raw)
        XCTAssertEqual(article?.title, "Hello")
        XCTAssertEqual(article?.byline, "Kurt")
        XCTAssertEqual(article?.paragraphs.count, 1)
    }

    func testBuildHTMLContainsTitleAndNoScript() {
        let html = ReaderMode.buildHTML(
            title: "Title <x>",
            byline: "Author",
            site: "example.com",
            paragraphs: [["tag": "p", "text": "Hello & welcome"]],
            dark: false
        )
        XCTAssertTrue(html.contains("Title &lt;x&gt;"))
        XCTAssertTrue(html.contains("Hello &amp; welcome"))
        XCTAssertFalse(html.contains("<script"))
    }
}
