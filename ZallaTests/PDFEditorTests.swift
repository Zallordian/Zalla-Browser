import XCTest
import PDFKit
import UIKit
@testable import Zalla

/// Build 48: Edit PDF gating, naming, and the saved signature.
final class PDFEditorTests: XCTestCase {
    func testEditPDFNeedsZallaUnlock() {
        XCTAssertEqual(PDFEditorGate.action(unlocked: false), .needsUnlock)
        XCTAssertEqual(PDFEditorGate.action(unlocked: true), .edit)
    }

    func testOnlyPDFsOffered() {
        XCTAssertTrue(PDFEditorGate.isPDF(URL(fileURLWithPath: "/tmp/Lease.PDF")))
        XCTAssertFalse(PDFEditorGate.isPDF(URL(fileURLWithPath: "/tmp/photo.png")))
        XCTAssertNil(PDFDocumentItem.incoming(URL(string: "https://example.com/a.pdf")!), "Web links are not files")
    }

    func testCopyName() {
        XCTAssertEqual(PDFEditorGate.copyName(for: URL(fileURLWithPath: "/tmp/Lease.pdf")), "Lease edited.pdf")
    }

    func testSignatureSavesLocallyAndDeletes() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SignatureStore(directory: folder)
        XCTAssertFalse(store.hasSignature)
        XCTAssertTrue(store.save(Data([1, 2, 3])))
        XCTAssertTrue(store.hasSignature)
        XCTAssertEqual(store.load(), Data([1, 2, 3]))
        store.delete()
        XCTAssertFalse(store.hasSignature)
        XCTAssertNil(store.load())
    }

    func testFlattenedCopyKeepsPages() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300))
        try renderer.writePDF(to: source) { context in
            context.beginPage()
            context.beginPage()
        }
        let expectation = expectation(description: "export")
        Task { @MainActor in
            let model = PDFEditorModel(url: source)
            model.addText("Hello")
            XCTAssertTrue(model.canUndo)
            model.undo()
            XCTAssertFalse(model.canUndo)
            model.addText("Signed")
            let copy = model.exportCopy()
            XCTAssertNotNil(copy)
            XCTAssertEqual(copy.flatMap { PDFDocument(url: $0) }?.pageCount, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }
}
