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

    func testSearchURLStaysHTTPSInApp() {
        let url = AddressResolver.searchURL(for: "privacy browser", engine: .duckDuckGo)!
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "duckduckgo.com")
        XCTAssertTrue(url.absoluteString.contains("privacy"))
    }
}

final class SearchEngineTests: XCTestCase {
    func testBraveIsTheDefaultAndOrderIsAsSpecified() {
        XCTAssertEqual(SearchEngine.defaultEngine, .brave)
        XCTAssertEqual(
            SearchEngine.allCases.map(\.rawValue),
            ["Google", "Bing", "DuckDuckGo", "Brave Search", "Startpage", "Ecosia", "Kagi", "Custom URL"]
        )
        XCTAssertEqual(SearchEngine.kagi.displayName, "Kagi (Paid)")
        XCTAssertEqual(SearchEngine(rawValue: "DuckDuckGo"), .duckDuckGo)
    }

    func testEveryEngineBuildsAnHTTPSSearch() {
        for engine in SearchEngine.allCases {
            let url = AddressResolver.searchURL(for: "zalla browser", engine: engine)
            XCTAssertEqual(url?.scheme, "https", "\(engine)")
            XCTAssertNotNil(url?.host)
        }
        XCTAssertEqual(AddressResolver.searchURL(for: "hi", engine: .startpage)?.query, "query=hi")
        XCTAssertEqual(AddressResolver.searchURL(for: "hi", engine: .brave)?.host, "search.brave.com")
    }

    func testCustomURLTemplate() {
        XCTAssertNil(SearchEngine.customURLTemplate(from: nil))
        XCTAssertNil(SearchEngine.customURLTemplate(from: "https://example.org/search"))
        XCTAssertNil(SearchEngine.customURLTemplate(from: "ftp://example.org/?q=%s"))
        let template = "https://example.org/find?term=%s&x=1"
        XCTAssertEqual(SearchEngine.customURLTemplate(from: template), template)
        let url = AddressResolver.searchURL(for: "a b&c", engine: .custom, customTemplate: template)
        XCTAssertEqual(url?.absoluteString, "https://example.org/find?term=a%20b%26c&x=1")
        XCTAssertEqual(AddressResolver.searchURL(for: "a", engine: .custom)?.host, "search.brave.com")
    }

    func testCustomOnlyOfferedWhenUsable() {
        XCTAssertFalse(SearchEngine.choices(customTemplate: "").contains(.custom))
        XCTAssertTrue(SearchEngine.choices(customTemplate: "https://x.org/?q=%s").contains(.custom))
        XCTAssertTrue(SearchEngine.choices(customTemplate: nil, selected: .custom).contains(.custom))
    }

    func testExistingUsersKeepDuckDuckGoAndNewInstallsGetBrave() {
        let existing = UserDefaults(suiteName: "zalla.engine.existing")!
        existing.removePersistentDomain(forName: "zalla.engine.existing")
        existing.set(true, forKey: "hasCompletedOnboarding")
        SearchEngine.keepExistingChoice(in: existing)
        XCTAssertEqual(existing.string(forKey: SearchEngine.storageKey), "DuckDuckGo")

        let chosen = UserDefaults(suiteName: "zalla.engine.chosen")!
        chosen.removePersistentDomain(forName: "zalla.engine.chosen")
        chosen.set(true, forKey: "hasCompletedOnboarding")
        chosen.set("Google", forKey: SearchEngine.storageKey)
        SearchEngine.keepExistingChoice(in: chosen)
        XCTAssertEqual(chosen.string(forKey: SearchEngine.storageKey), "Google")

        let fresh = UserDefaults(suiteName: "zalla.engine.fresh")!
        fresh.removePersistentDomain(forName: "zalla.engine.fresh")
        SearchEngine.keepExistingChoice(in: fresh)
        XCTAssertNil(fresh.string(forKey: SearchEngine.storageKey))
        fresh.set(true, forKey: "hasCompletedOnboarding")
        SearchEngine.keepExistingChoice(in: fresh)
        XCTAssertNil(fresh.string(forKey: SearchEngine.storageKey), "Runs once, so a new install is never switched later")
    }
}
