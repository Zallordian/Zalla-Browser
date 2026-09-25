import XCTest
@testable import Zalla

final class NetworkSpeedTests: XCTestCase {
    func testEndpointURLsAreHTTPS() {
        XCTAssertEqual(NetworkSpeedEndpoints.latencyURL.scheme, "https")
        XCTAssertEqual(NetworkSpeedEndpoints.uploadURL.scheme, "https")
        let down = NetworkSpeedEndpoints.downloadURL(bytes: 1000)
        XCTAssertEqual(down.scheme, "https")
        XCTAssertTrue(down.absoluteString.contains("1000"))
    }

    func testTransferSizesAvoidRejectedValues() {
        // speed.cloudflare.com answers 403 for 12.5 MB, which broke Build 10.
        XCTAssertFalse(NetworkSpeedEndpoints.downloadSizes.contains(12_500_000))
        XCTAssertEqual(NetworkSpeedEndpoints.downloadSizes.first, 10_000_000)
        XCTAssertTrue(NetworkSpeedEndpoints.downloadSizes.allSatisfy { $0 > 0 && $0 <= 25_000_000 })
        XCTAssertTrue(NetworkSpeedEndpoints.uploadSizes.allSatisfy { $0 > 0 && $0 <= 10_000_000 })
    }

    func testFriendlyMessagesHideRawErrors() {
        let bad = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)
        XCTAssertEqual(NetworkSpeedMessages.friendlyMessage(for: bad), NetworkSpeedMessages.unreachable)
        XCTAssertFalse(NetworkSpeedMessages.friendlyMessage(for: bad).contains("-1011"))
        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertEqual(NetworkSpeedMessages.friendlyMessage(for: offline), NetworkSpeedMessages.offline)
        let timeout = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertEqual(NetworkSpeedMessages.friendlyMessage(for: timeout), NetworkSpeedMessages.timedOut)
    }
}
