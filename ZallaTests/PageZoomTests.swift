import XCTest
@testable import Zalla

final class PageZoomTests: XCTestCase {
    func testStepsStayInRange() {
        XCTAssertEqual(PageZoom.next(after: 1.0), 1.15)
        XCTAssertEqual(PageZoom.previous(before: 1.0), 0.85)
        XCTAssertEqual(PageZoom.next(after: 3.0), 3.0)
        XCTAssertEqual(PageZoom.previous(before: 0.5), 0.5)
        XCTAssertEqual(PageZoom.clamped(9), 3.0)
        XCTAssertEqual(PageZoom.clamped(0.1), 0.5)
        XCTAssertEqual(PageZoom.percentText(1.15), "115%")
        XCTAssertEqual(PageZoom.percentText(0.5), "50%")
    }

    func testPerHostStore() {
        var store: [String: Double] = [:]
        store = PageZoom.updated(store, host: "a.test", level: 1.5)
        XCTAssertEqual(PageZoom.level(for: "a.test", in: store), 1.5)
        XCTAssertEqual(PageZoom.level(for: "b.test", in: store), 1.0)
        store = PageZoom.updated(store, host: "a.test", level: 1.0)
        XCTAssertTrue(store.isEmpty, "Resetting to 100% forgets the site")
        XCTAssertEqual(PageZoom.hostKey(for: URL(string: "https://News.Example.com/a")), "news.example.com")
        XCTAssertNil(PageZoom.hostKey(for: URL(string: "about:blank")))
    }

    func testPersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: "PageZoomTests")!
        defaults.removePersistentDomain(forName: "PageZoomTests")
        PageZoom.save(["a.test": 1.25], to: defaults)
        XCTAssertEqual(PageZoom.load(from: defaults), ["a.test": 1.25])
        PageZoom.save([:], to: defaults)
        XCTAssertTrue(PageZoom.load(from: defaults).isEmpty)
        defaults.removePersistentDomain(forName: "PageZoomTests")
    }
}
