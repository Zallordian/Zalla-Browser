import XCTest
import UIKit
@testable import Zalla

/// Build 48: site icons.
final class FaviconTests: XCTestCase {
    let page = URL(string: "https://www.wps.com/office/")!

    func testSizesParsing() {
        XCTAssertEqual(FaviconPicker.largestSide("16x16 32x32"), 32)
        XCTAssertEqual(FaviconPicker.largestSide("180X180"), 180)
        XCTAssertEqual(FaviconPicker.largestSide("any"), 0)
        XCTAssertEqual(FaviconPicker.largestSide(nil), 0)
    }

    func testOrderPrefersLargestRasterThenRootThenSVG() {
        let links = [
            ["href": "/icon.svg", "rel": "icon", "type": "image/svg+xml"],
            ["href": "/fav-16.png", "rel": "icon", "sizes": "16x16"],
            ["href": "/apple-touch-icon.png", "rel": "apple-touch-icon"],
            ["href": "https://cdn.wps.com/i/192.webp", "rel": "icon", "sizes": "192x192"]
        ]
        let order = FaviconPicker.ordered(FaviconPicker.candidates(from: links, pageURL: page), pageURL: page)
        XCTAssertEqual(order.map(\.absoluteString), [
            "https://cdn.wps.com/i/192.webp",
            "https://www.wps.com/apple-touch-icon.png",
            "https://www.wps.com/fav-16.png",
            "https://www.wps.com/favicon.ico",
            "https://www.wps.com/icon.svg"
        ])
    }

    func testNoLinksFallsBackToRootFavicon() {
        XCTAssertEqual(FaviconPicker.ordered([], pageURL: page), [URL(string: "https://www.wps.com/favicon.ico")!])
    }

    func testHttpIconOnHttpsPageIsUpgradedAndJunkIgnored() {
        let links = [["href": "http://www.wps.com/a.png", "rel": "icon"], ["href": "javascript:alert(1)", "rel": "icon"], ["rel": "icon"]]
        let candidates = FaviconPicker.candidates(from: links, pageURL: page)
        XCTAssertEqual(candidates.map(\.url.absoluteString), ["https://www.wps.com/a.png"])
    }

    func testManifestIcons() {
        let json = #"{"icons":[{"src":"/m-512.png","sizes":"512x512","type":"image/png"},{"nope":1}]}"#
        let links = FaviconPicker.manifestLinks(Data(json.utf8))
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?["sizes"], "512x512")
        XCTAssertTrue(FaviconPicker.manifestLinks(Data("junk".utf8)).isEmpty)
    }

    func testKeysAndLetters() {
        XCTAssertEqual(FaviconPicker.key(for: "WWW.WPS.com"), "wps.com")
        XCTAssertNil(FaviconPicker.key(for: nil))
        XCTAssertEqual(FaviconPicker.letter(for: "www.wps.com"), "W")
        XCTAssertEqual(FaviconPicker.letter(for: "9gag.com"), "9")
        XCTAssertEqual(FaviconPicker.letter(for: nil), "?")
    }

    @MainActor
    func testCacheStoresAndBurnClears() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FaviconStore(directory: folder)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        store.store(image, for: "wps.com")
        XCTAssertNotNil(store.image(for: "www.wps.com"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL(for: "wps.com").path))
        store.removeAll()
        XCTAssertNil(store.image(for: "wps.com"))
    }

    func testDecodeRejectsNonImages() {
        XCTAssertNil(FaviconStore.decode(Data("<svg></svg>".utf8)))
        let png = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }.pngData()!
        XCTAssertEqual(FaviconStore.decode(png)?.size, CGSize(width: 64, height: 64))
    }
}
