import XCTest
@testable import Zalla

final class ImageHoldTests: XCTestCase {
    private func report(held: Double = 600, moved: Double = 0, touches: Int = 1) -> ImageHold.Report {
        ImageHold.Report(src: "https://example.com/a.png", heldMs: held, moved: moved, touches: touches)
    }

    func testStillHoldIsAccepted() {
        XCTAssertTrue(ImageHold.accepts(report(), scrolling: false, sheetShowing: false))
    }

    func testShortHoldMovementAndMultiTouchAreRejected() {
        XCTAssertFalse(ImageHold.accepts(report(held: 300), scrolling: false, sheetShowing: false))
        XCTAssertFalse(ImageHold.accepts(report(moved: 11), scrolling: false, sheetShowing: false))
        XCTAssertFalse(ImageHold.accepts(report(touches: 2), scrolling: false, sheetShowing: false))
    }

    func testNeverWhileScrollingOrWithASheetUp() {
        XCTAssertFalse(ImageHold.accepts(report(), scrolling: true, sheetShowing: false))
        XCTAssertFalse(ImageHold.accepts(report(), scrolling: false, sheetShowing: true))
    }

    func testOldOrForeignMessagesAreIgnored() {
        XCTAssertNil(ImageHold.Report(body: ["src": "https://example.com/a.png"]))
        XCTAssertNil(ImageHold.Report(body: "hello"))
        let body: [String: Any] = ["src": "https://example.com/a.png", "held": 620, "moved": 3, "touches": 1]
        XCTAssertEqual(ImageHold.Report(body: body), report(held: 620, moved: 3))
    }

    func testScriptGuardsTheHold() {
        let script = ImageHold.script
        for needle in ["touchcancel", "capture: true", "isTrusted", "touches.length !== 1", "'scroll'"] {
            XCTAssertTrue(script.contains(needle), needle)
        }
        XCTAssertFalse(script.contains("contextmenu"))
    }
}

final class NavigationErrorTests: XCTestCase {
    func testBenignErrorsStayQuiet() {
        XCTAssertFalse(FriendlyErrorKind.shouldShow(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        for code in [101, 102, 204] {
            XCTAssertFalse(FriendlyErrorKind.shouldShow(NSError(domain: "WebKitErrorDomain", code: code)))
        }
        XCTAssertFalse(FriendlyErrorKind.shouldShow(NSError(domain: "WKErrorDomain", code: 1)))
    }

    func testRealFailuresStillShow() {
        for code in [NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost, NSURLErrorTimedOut] {
            XCTAssertTrue(FriendlyErrorKind.shouldShow(NSError(domain: NSURLErrorDomain, code: code)))
        }
    }

    func testResumeRetriesOnceInsideTheWindow() {
        let now = Date()
        let lost = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        let until = now.addingTimeInterval(ResumeRetry.window)
        XCTAssertTrue(ResumeRetry.shouldRetry(lost, now: now, until: until, alreadyRetried: false))
        XCTAssertFalse(ResumeRetry.shouldRetry(lost, now: now, until: until, alreadyRetried: true))
        XCTAssertFalse(ResumeRetry.shouldRetry(lost, now: now, until: nil, alreadyRetried: false))
        XCTAssertFalse(ResumeRetry.shouldRetry(lost, now: until.addingTimeInterval(1), until: until, alreadyRetried: false))
        let badCert = NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)
        XCTAssertFalse(ResumeRetry.shouldRetry(badCert, now: now, until: until, alreadyRetried: false))
    }
}
