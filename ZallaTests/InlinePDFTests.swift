import XCTest
@testable import Zalla

/// Build 49: PDFs open in the tab instead of turning into a silent download.
final class InlinePDFTests: XCTestCase {
    private func response(_ url: String, mime: String?, headers: [String: String] = [:]) -> URLResponse {
        var all = headers
        if let mime { all["Content-Type"] = mime }
        return HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: "HTTP/2", headerFields: all)!
    }

    func testIRSFormOpensInline() {
        // What irs.gov actually sends for fss4.pdf (checked with curl): application/pdf, no Content-Disposition.
        let irs = response("https://www.irs.gov/pub/irs-pdf/fss4.pdf", mime: "application/pdf",
                           headers: ["Content-Length": "122921", "X-Content-Type-Options": "nosniff"])
        XCTAssertTrue(DownloadsStore.isInlinePDF(response: irs))
    }

    func testAttachmentStillDownloads() {
        let attachment = response("https://example.com/f.pdf", mime: "application/pdf",
                                  headers: ["Content-Disposition": "attachment; filename=f.pdf"])
        XCTAssertFalse(DownloadsStore.isInlinePDF(response: attachment))
        XCTAssertTrue(DownloadsStore.isLikelyDownload(response: attachment))
    }

    func testGenericBinaryWithPDFPathIsInline() {
        XCTAssertTrue(DownloadsStore.isInlinePDF(response: response("https://example.com/a.pdf", mime: "application/octet-stream")))
        XCTAssertFalse(DownloadsStore.isInlinePDF(response: response("https://example.com/a.zip", mime: "application/octet-stream")))
        XCTAssertFalse(DownloadsStore.isInlinePDF(response: response("https://example.com/", mime: "text/html")))
    }

    func testBlobPDFIsNotInline() {
        let blob = URLResponse(url: URL(string: "blob:https://example.com/123")!, mimeType: "application/pdf",
                               expectedContentLength: -1, textEncodingName: nil)
        XCTAssertFalse(DownloadsStore.isInlinePDF(response: blob))
    }

    func testTabCopyChecksAndNames() {
        XCTAssertTrue(PDFTabCopy.looksLikePDF(Data("%PDF-1.7\n...".utf8)))
        XCTAssertFalse(PDFTabCopy.looksLikePDF(Data("<html>".utf8)))
        XCTAssertEqual(PDFTabCopy.safeName("fss4.pdf"), "fss4.pdf")
        XCTAssertEqual(PDFTabCopy.safeName("form"), "form.pdf")
        XCTAssertEqual(PDFTabCopy.safeName(""), "Document.pdf")
        let url = PDFTabCopy.write(Data("%PDF-1.4".utf8), name: "x.pdf")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.lastPathComponent, "x.pdf")
    }
}
