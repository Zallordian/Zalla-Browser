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
}
