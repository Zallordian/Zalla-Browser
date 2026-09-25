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
            "http://[fe80::1]/"
        ]
        for string in local {
            XCTAssertNil(HTTPSOnly.upgradedURL(for: URL(string: string)!), string)
        }
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
        XCTAssertFalse(HTTPSOnly.isUpgradeFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertTrue(HTTPSOnly.isInterruption(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertTrue(HTTPSOnly.isInterruption(NSError(domain: "WebKitErrorDomain", code: 102)))
        XCTAssertFalse(HTTPSOnly.isInterruption(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)))
    }

    func testNoticeCopy() {
        XCTAssertEqual(HTTPSOnly.goBackTitle, "Go Back")
        XCTAssertEqual(HTTPSOnly.continueTitle, "Continue to Site")
        XCTAssertTrue(HTTPSOnly.noticeMessage(host: "example.com").hasPrefix("example.com"))
        let dash = String(UnicodeScalar(0x2014)!)
        XCTAssertFalse(HTTPSOnly.noticeTitle.contains(dash))
        XCTAssertFalse(HTTPSOnly.noticeMessage(host: "a.test").contains(dash))
    }
}
