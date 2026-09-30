import XCTest
@testable import Zalla

final class HTTPSOnlyTests: XCTestCase {
    func testUpgradesPlainHTTP() {
        let url = URL(string: "http://example.com/path?q=1#top")!
        XCTAssertEqual(HTTPSOnly.upgradedURL(for: url)?.absoluteString, "https://example.com/path?q=1#top")
    }

    func testDropsDefaultPortAndKeepsCustomPort() {
        XCTAssertEqual(
            HTTPSOnly.upgradedURL(for: URL(string: "http://example.com:80/a")!)?.absoluteString,
            "https://example.com/a"
        )
        XCTAssertEqual(
            HTTPSOnly.upgradedURL(for: URL(string: "http://example.com:8080/a")!)?.absoluteString,
            "https://example.com:8080/a"
        )
    }

    func testLeavesHTTPSAndOtherSchemesAlone() {
        XCTAssertNil(HTTPSOnly.upgradedURL(for: URL(string: "https://example.com")!))
        XCTAssertNil(HTTPSOnly.upgradedURL(for: URL(string: "about:blank")!))
        XCTAssertNil(HTTPSOnly.upgradedURL(for: URL(string: "mailto:a@example.com")!))
    }

    func testSkipsLocalAndPrivateHosts() {
        let local = [
            "http://localhost/",
            "http://localhost:3000/",
            "http://app.localhost/",
            "http://127.0.0.1/",
            "http://127.4.5.6:8000/",
            "http://printer.local/",
            "http://router/",
            "http://10.0.0.5/",
            "http://172.16.0.1/",
            "http://172.31.255.255/",
            "http://192.168.1.1/",
            "http://169.254.10.20/",
            "http://[::1]:8080/",
            "http://[fd12:3456::1]/",
            "http://[fe80::1]/",
            "http://100.64.0.1/",
            "http://100.127.255.254/",
            "http://[::]/",
            "http://[::ffff:127.0.0.1]/",
            "http://[::ffff:10.1.2.3]/",
            "http://[::ffff:c0a8:101]/"
        ]
        for string in local {
            XCTAssertNil(HTTPSOnly.upgradedURL(for: URL(string: string)!), string)
        }
    }

    func testSharedAddressRangeEndsAtItsEdges() {
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://100.63.255.255/")!))
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://100.128.0.1/")!))
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://[::ffff:8.8.8.8]/")!))
    }

    func testUpgradesPublicIPs() {
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://172.32.0.1/")!))
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://8.8.8.8/")!))
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://[2606:4700::1111]/")!))
    }

    func testExceptionsAreCaseInsensitiveAndPerHost() {
        var exceptions = HTTPSOnlyExceptions()
        XCTAssertTrue(exceptions.isEmpty)
        exceptions.allow("Example.COM")
        XCTAssertTrue(exceptions.contains("example.com"))
        XCTAssertNil(HTTPSOnly.upgradedURL(for: URL(string: "http://example.com/a")!, exceptions: exceptions))
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://other.example/")!, exceptions: exceptions))
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://www.example.com/")!, exceptions: exceptions))
        exceptions.removeAll()
        XCTAssertNotNil(HTTPSOnly.upgradedURL(for: URL(string: "http://example.com/a")!, exceptions: exceptions))
    }

    func testFailureClassification() {
        XCTAssertTrue(HTTPSOnly.isUpgradeFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)))
        XCTAssertTrue(HTTPSOnly.isUpgradeFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)))
        XCTAssertTrue(HTTPSOnly.isUpgradeFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)))
        XCTAssertFalse(HTTPSOnly.isUpgradeFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)))
        XCTAssertFalse(HTTPSOnly.isUpgradeFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)))
        XCTAssertFalse(HTTPSOnly.isUpgradeFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertTrue(HTTPSOnly.isInterruption(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertTrue(HTTPSOnly.isInterruption(NSError(domain: "WebKitErrorDomain", code: 102)))
        XCTAssertFalse(HTTPSOnly.isInterruption(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)))
    }

    func testNoticeCopy() {
        XCTAssertEqual(HTTPSOnly.noticeTitle, "This site doesn't use encryption.")
        XCTAssertEqual(HTTPSOnly.goBackTitle, "Take me back")
        XCTAssertEqual(HTTPSOnly.continueTitle, "Continue anyway")
        XCTAssertTrue(HTTPSOnly.noticeMessage.hasPrefix("Anything you type here"))
        let dash = String(UnicodeScalar(0x2014)!)
        XCTAssertFalse(HTTPSOnly.noticeTitle.contains(dash))
        XCTAssertFalse(HTTPSOnly.noticeMessage.contains(dash))
    }

    func testOnByDefaultUnlessTurnedOff() {
        let defaults = UserDefaults(suiteName: "zalla.https.default")!
        defaults.removePersistentDomain(forName: "zalla.https.default")
        XCTAssertTrue(HTTPSOnly.enabled(in: defaults), "Nothing stored means on")
        defaults.set(false, forKey: HTTPSOnly.storageKey)
        XCTAssertFalse(HTTPSOnly.enabled(in: defaults), "A saved choice wins")
        defaults.set(true, forKey: HTTPSOnly.storageKey)
        XCTAssertTrue(HTTPSOnly.enabled(in: defaults))
    }
}

final class FriendlyErrorTests: XCTestCase {
    private func error(_ code: Int) -> NSError { NSError(domain: NSURLErrorDomain, code: code) }

    func testClassifiesCommonFailures() {
        XCTAssertEqual(FriendlyErrorKind.classify(error(NSURLErrorNotConnectedToInternet)), .offline)
        XCTAssertEqual(FriendlyErrorKind.classify(error(NSURLErrorTimedOut)), .timeout)
        XCTAssertEqual(FriendlyErrorKind.classify(error(NSURLErrorServerCertificateUntrusted)), .badCertificate)
        XCTAssertEqual(FriendlyErrorKind.classify(error(NSURLErrorCannotFindHost)), .notFound)
        XCTAssertEqual(FriendlyErrorKind.classify(error(NSURLErrorCannotConnectToHost)), .cannotConnect)
        XCTAssertEqual(FriendlyErrorKind.classify(NSError(domain: "other", code: 1)), .other)
    }

    func testCopyIsPresentAndHasNoEmDash() {
        let dash = String(UnicodeScalar(0x2014)!)
        for kind in [FriendlyErrorKind.offline, .timeout, .badCertificate, .notFound, .cannotConnect, .other] {
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertFalse(kind.message.isEmpty)
            XCTAssertFalse(kind.title.contains(dash))
            XCTAssertFalse(kind.message.contains(dash))
        }
        XCTAssertFalse(FriendlyErrorKind.badCertificate.offersRetry)
    }

    func testFailingURLIsPickedUp() {
        let url = URL(string: "https://example.com/x")!
        let failure = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSURLErrorFailingURLErrorKey: url])
        XCTAssertEqual(FriendlyError(error: failure, fallbackURL: nil).host, "example.com")
    }
}

final class BrowserBehaviorTests: XCTestCase {
    func testSwipeNavigationDefaultsOn() {
        let defaults = UserDefaults(suiteName: "zalla.swipe.tests")!
        defaults.removePersistentDomain(forName: "zalla.swipe.tests")
        XCTAssertTrue(SwipeNavigation.enabled(in: defaults))
        defaults.set(false, forKey: SwipeNavigation.storageKey)
        XCTAssertFalse(SwipeNavigation.enabled(in: defaults))
    }

    func testDesktopSiteIsRememberedPerHost() {
        let defaults = UserDefaults(suiteName: "zalla.desktop.tests")!
        defaults.removePersistentDomain(forName: "zalla.desktop.tests")
        let url = URL(string: "https://www.example.com/page")!
        XCTAssertFalse(DesktopSitePreference.isDesktop(url, in: defaults))
        DesktopSitePreference.set(true, for: url, in: defaults)
        XCTAssertTrue(DesktopSitePreference.isDesktop(URL(string: "https://example.com/other"), in: defaults))
        XCTAssertFalse(DesktopSitePreference.isDesktop(URL(string: "https://example.org"), in: defaults))
        DesktopSitePreference.set(false, for: url, in: defaults)
        XCTAssertFalse(DesktopSitePreference.isDesktop(url, in: defaults))
    }
}

final class IncomingLinkTests: XCTestCase {
    func testWebAndZallaLinks() {
        XCTAssertEqual(IncomingLink.webURL(from: URL(string: "https://example.com/a")!)?.absoluteString, "https://example.com/a")
        XCTAssertEqual(IncomingLink.webURL(from: URL(string: "zalla://open?url=https://example.org/x")!)?.absoluteString, "https://example.org/x")
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "zalla://open?url=javascript:alert(1)")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "file:///etc/passwd")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "zalla://open")!))
    }

    func testOnlyHTTPAndHTTPSTargetsWithAHostAreOpened() {
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "zalla://open?url=ftp://example.com/file")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "zalla://open?url=data:text/html,hi")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "zalla://open?url=file:///etc/hosts")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "zalla://open?url=https://")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "zalla://open?url=")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "zalla://open?other=https://example.com")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "mailto:someone@example.com")!))
        XCTAssertNil(IncomingLink.webURL(from: URL(string: "tel:5551234")!))
        XCTAssertEqual(IncomingLink.webURL(from: URL(string: "ZALLA://open?url=HTTPS://example.com/Path")!)?.host, "example.com")
    }

    func testEncodedTargetsAreDecodedOnce() {
        let link = URL(string: "zalla://open?url=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1%26c%3D2")!
        XCTAssertEqual(IncomingLink.webURL(from: link)?.absoluteString, "https://example.com/a?b=1&c=2")
    }
}
