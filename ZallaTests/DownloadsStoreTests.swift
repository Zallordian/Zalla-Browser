import XCTest
@testable import Zalla

final class DownloadsStoreTests: XCTestCase {
    func testSanitizeFilename() {
        XCTAssertEqual(DownloadsStore.sanitizeFilename("report/final:v1.pdf"), "report-final-v1.pdf")
        XCTAssertEqual(DownloadsStore.sanitizeFilename("   "), "download")
    }

    func testDownloadRecordCodableRoundTrip() throws {
        let record = DownloadRecord(
            filename: "notes.pdf",
            sourceURL: URL(string: "https://files.example/notes.pdf")!,
            localRelativePath: "notes.pdf",
            byteCount: 1234,
            state: .completed,
            isPrivate: true
        )
        let data = try JSONEncoder().encode([record])
        let decoded = try JSONDecoder().decode([DownloadRecord].self, from: data)
        XCTAssertEqual(decoded, [record])
    }

    func testLikelyDownloadMIME() {
        let pdf = URLResponse(
            url: URL(string: "https://example.com/a.pdf")!,
            mimeType: "application/pdf",
            expectedContentLength: 10,
            textEncodingName: nil
        )
        XCTAssertTrue(DownloadsStore.isLikelyDownload(response: pdf))

        let html = URLResponse(
            url: URL(string: "https://example.com/")!,
            mimeType: "text/html",
            expectedContentLength: 10,
            textEncodingName: nil
        )
        XCTAssertFalse(DownloadsStore.isLikelyDownload(response: html))
    }

    func testBlobURLIsLikelyDownload() {
        let blob = URLResponse(
            url: URL(string: "blob:https://example.com/uuid")!,
            mimeType: "application/octet-stream",
            expectedContentLength: -1,
            textEncodingName: nil
        )
        XCTAssertTrue(DownloadsStore.isLikelyDownload(response: blob))
    }

    func testDataURLIsLikelyDownload() {
        let data = URLResponse(
            url: URL(string: "data:application/octet-stream;base64,AAA")!,
            mimeType: "application/octet-stream",
            expectedContentLength: -1,
            textEncodingName: nil
        )
        XCTAssertTrue(DownloadsStore.isLikelyDownload(response: data))
    }

    func testDownloadQueryHint() {
        let response = URLResponse(
            url: URL(string: "https://cdn.example/file?download=1")!,
            mimeType: "application/octet-stream",
            expectedContentLength: 10,
            textEncodingName: nil
        )
        XCTAssertTrue(DownloadsStore.isLikelyDownload(response: response))
    }
}
