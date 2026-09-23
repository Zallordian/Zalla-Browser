import XCTest
@testable import Zalla

final class AddressResolverTests: XCTestCase {
    func testEmptyAddressDoesNotNavigate() {
        XCTAssertNil(AddressResolver.resolve("  \n", engine: .duckDuckGo))
    }

    func testBareDomainUsesHTTPS() {
        XCTAssertEqual(AddressResolver.resolve("example.com/path?a=1", engine: .duckDuckGo)?.absoluteString,
                       "https://example.com/path?a=1")
    }

    func testExplicitHTTPIsPreserved() {
        XCTAssertEqual(AddressResolver.resolve("http://example.com", engine: .duckDuckGo)?.scheme, "http")
    }

    func testQueriesAreEncodedWithoutLosingCharacters() {
        let url = AddressResolver.resolve("cats & dogs + tea", engine: .google)!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.queryItems?.first?.value, "cats & dogs + tea")
        XCTAssertTrue(url.absoluteString.contains("%2B"))
    }

    func testExecutableInputBecomesSearchNotNavigation() {
        let url = AddressResolver.resolve("javascript:alert(1)", engine: .duckDuckGo)!
        XCTAssertEqual(url.host, "duckduckgo.com")
        XCTAssertEqual(url.scheme, "https")
    }

    func testUnsupportedSchemeBecomesSearch() {
        XCTAssertEqual(AddressResolver.resolve("file:///etc/passwd", engine: .bing)?.host, "www.bing.com")
    }
}
