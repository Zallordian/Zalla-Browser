import XCTest
@testable import Zalla

final class ImageExportFormatTests: XCTestCase {
    func testFormatsTheDeviceCannotWriteAreNotListed() {
        let supported = ["public.png", "public.jpeg", "public.heic"]
        let listed = ImageExportFormat.filtered(ImageExportFormat.allCases, supportedIdentifiers: supported)
        XCTAssertEqual(listed, [.png, .jpeg, .heic])
    }

    func testEveryFormatIsListedWhenSupported() {
        let supported = ImageExportFormat.allCases.map { $0.utType.identifier }
        let listed = ImageExportFormat.filtered(ImageExportFormat.allCases, supportedIdentifiers: supported)
        XCTAssertEqual(listed, ImageExportFormat.allCases)
    }

    func testPNGAndJPEGAreAlwaysOffered() {
        let listed = ImageExportFormat.filtered(ImageExportFormat.allCases, supportedIdentifiers: [])
        XCTAssertEqual(listed, [.png, .jpeg])
        XCTAssertTrue(ImageExportFormat.available.contains(.png))
    }
}
