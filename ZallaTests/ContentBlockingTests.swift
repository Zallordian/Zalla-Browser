import XCTest
@testable import Zalla

final class ContentBlockingTests: XCTestCase {
    func testDefaultsBlockFreeListsOnly() {
        let settings = ContentBlockingSettings()
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.activeCategories(unlocked: false), [.trackers, .commonAds])
        XCTAssertEqual(settings.activeCategories(unlocked: true), BlocklistCategory.allCases)
    }

    func testDisabledCategoriesAreSkipped() {
        var settings = ContentBlockingSettings()
        settings.set(.commonAds, on: false)
        settings.set(.annoyances, on: false)
        XCTAssertEqual(settings.activeCategories(unlocked: true), [.trackers, .fullAds, .adSpaces])
        settings.set(.commonAds, on: true)
        XCTAssertTrue(settings.isOn(.commonAds))
        XCTAssertEqual(settings.disabledCategories, ["annoyances"])
    }

    func testHostKeyDropsWWW() {
        XCTAssertEqual(ContentBlockingSettings.hostKey(for: URL(string: "https://WWW.Example.com/a")), "example.com")
        XCTAssertEqual(ContentBlockingSettings.hostKey(for: URL(string: "https://news.example.com")), "news.example.com")
        XCTAssertNil(ContentBlockingSettings.hostKey(for: nil))
    }

    func testShouldBlockSkipsLocalAndNonWebPages() {
        let settings = ContentBlockingSettings()
        XCTAssertTrue(settings.shouldBlock(url: URL(string: "https://example.com")))
        XCTAssertFalse(settings.shouldBlock(url: URL(string: "http://localhost:8080")))
        XCTAssertFalse(settings.shouldBlock(url: URL(string: "http://192.168.1.10")))
        XCTAssertFalse(settings.shouldBlock(url: URL(string: "http://printer.local")))
        XCTAssertFalse(settings.shouldBlock(url: URL(string: "about:blank")))
        XCTAssertFalse(settings.shouldBlock(url: nil))
    }

    func testMasterSwitchOff() {
        var settings = ContentBlockingSettings()
        settings.isEnabled = false
        XCTAssertFalse(settings.shouldBlock(url: URL(string: "https://example.com")))
    }

    func testPerSiteToggleCoversSubdomains() {
        var settings = ContentBlockingSettings()
        settings.setBlocking(false, forHost: "example.com")
        XCTAssertFalse(settings.shouldBlock(url: URL(string: "https://www.example.com/page")))
        XCTAssertFalse(settings.shouldBlock(url: URL(string: "https://shop.example.com")))
        XCTAssertTrue(settings.shouldBlock(url: URL(string: "https://notexample.com")))
        settings.setBlocking(false, forHost: "shop.example.com")
        XCTAssertEqual(settings.allowedHosts, ["example.com"])
        settings.setBlocking(true, forHost: "shop.example.com")
        XCTAssertTrue(settings.allowedHosts.isEmpty)
        XCTAssertTrue(settings.shouldBlock(url: URL(string: "https://example.com")))
    }

    func testUserInputHosts() {
        XCTAssertEqual(ContentBlockingSettings.normalizedHost(fromUserInput: " Ads.Example.com "), "ads.example.com")
        XCTAssertEqual(ContentBlockingSettings.normalizedHost(fromUserInput: "https://www.tracker.net/x?y=1"), "tracker.net")
        XCTAssertNil(ContentBlockingSettings.normalizedHost(fromUserInput: ""))
        XCTAssertNil(ContentBlockingSettings.normalizedHost(fromUserInput: "localhost"))
        XCTAssertNil(ContentBlockingSettings.normalizedHost(fromUserInput: "not a domain"))
        var settings = ContentBlockingSettings()
        XCTAssertTrue(settings.addCustomBlock(fromUserInput: "ads.example.com"))
        XCTAssertFalse(settings.addCustomBlock(fromUserInput: "ads.example.com"))
        XCTAssertTrue(settings.addAllowedHost(fromUserInput: "example.org"))
        XCTAssertEqual(settings.allowedHosts, ["example.org"])
    }

    func testUserRulesNeedUnlock() {
        var settings = ContentBlockingSettings()
        settings.addCustomBlock(fromUserInput: "ads.example.com")
        XCTAssertTrue(settings.userRules(unlocked: false).isEmpty)
        let rules = settings.userRules(unlocked: true)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].action.type, "block")
        XCTAssertEqual(rules[0].trigger.urlFilter, "^[a-z-]+://([^/]+\\.)?ads\\.example\\.com[/:]")
    }

    func testHiddenElementsGroupPerHost() {
        var settings = ContentBlockingSettings()
        XCTAssertTrue(settings.addHiddenElement(selector: "#banner", host: "example.com"))
        XCTAssertTrue(settings.addHiddenElement(selector: "div.promo > p", host: "example.com"))
        XCTAssertFalse(settings.addHiddenElement(selector: "#banner", host: "example.com"))
        XCTAssertFalse(settings.addHiddenElement(selector: "a { color: red }", host: "example.com"))
        XCTAssertTrue(settings.addHiddenElement(selector: ".cookie", host: "other.org"))
        let rules = settings.userRules(unlocked: true)
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules[0].trigger.ifDomain, ["*example.com"])
        XCTAssertEqual(rules[0].action.type, "css-display-none")
        XCTAssertEqual(rules[0].action.selector, "#banner, div.promo > p")
        XCTAssertEqual(rules[1].trigger.ifDomain, ["*other.org"])
    }

    func testEncodedRulesUseWebKitKeys() throws {
        var settings = ContentBlockingSettings()
        settings.addHiddenElement(selector: ".ad", host: "example.com")
        let json = try XCTUnwrap(ContentBlockingSettings.encoded(settings.userRules(unlocked: true)))
        XCTAssertTrue(json.contains("\"url-filter\""))
        XCTAssertTrue(json.contains("\"if-domain\""))
        XCTAssertTrue(json.contains("\"css-display-none\""))
        XCTAssertFalse(json.contains("urlFilter"))
    }

    func testSplitRespectsLimit() {
        let items = Array(0..<10)
        XCTAssertEqual(ContentBlockingSettings.split(items, limit: 4), [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9]])
        XCTAssertEqual(ContentBlockingSettings.split([Int](), limit: 4), [])
        XCTAssertEqual(ContentBlockingSettings.split(items).count, 1)
        XCTAssertEqual(ContentBlockingSettings.ruleLimit, 150_000)
    }

    func testIdentifiersIncludeVersion() {
        let part = BlocklistManifest.Part(name: "privacy", resource: "blocklist-privacy", rules: 10, version: "abc123")
        XCTAssertEqual(ContentBlockingSettings.identifier(for: part), "zalla.privacy.abc123")
        let first = ContentBlockingSettings.userIdentifier(forJSON: "[1]", index: 0)
        XCTAssertEqual(first, ContentBlockingSettings.userIdentifier(forJSON: "[1]", index: 0))
        XCTAssertNotEqual(first, ContentBlockingSettings.userIdentifier(forJSON: "[2]", index: 0))
        XCTAssertTrue(first.hasPrefix("zalla.user0."))
    }

    func testRecompileOnlyForListChanges() {
        let base = ContentBlockingSettings()
        var allowed = base
        allowed.setBlocking(false, forHost: "example.com")
        XCTAssertFalse(allowed.needsRecompile(comparedTo: base))
        var custom = base
        custom.addCustomBlock(fromUserInput: "ads.example.com")
        XCTAssertTrue(custom.needsRecompile(comparedTo: base))
    }

    func testPersistenceRoundTripAndPartialDecode() throws {
        let defaults = UserDefaults(suiteName: "ContentBlockingTests")!
        defaults.removePersistentDomain(forName: "ContentBlockingTests")
        XCTAssertEqual(ContentBlockingSettings.load(from: defaults), ContentBlockingSettings())
        var settings = ContentBlockingSettings()
        settings.isEnabled = false
        settings.setBlocking(false, forHost: "example.com")
        settings.addHiddenElement(selector: ".ad", host: "example.com")
        settings.save(to: defaults)
        XCTAssertEqual(ContentBlockingSettings.load(from: defaults), settings)
        let partial = try JSONDecoder().decode(ContentBlockingSettings.self, from: Data("{\"allowedHosts\":[\"a.com\"]}".utf8))
        XCTAssertTrue(partial.isEnabled)
        XCTAssertEqual(partial.allowedHosts, ["a.com"])
        defaults.removePersistentDomain(forName: "ContentBlockingTests")
    }

    func testBundledManifestFitsAppleLimit() throws {
        let manifest = try XCTUnwrap(BlocklistManifest.load())
        for category in BlocklistCategory.allCases {
            let parts = manifest.parts(for: category)
            XCTAssertFalse(parts.isEmpty, category.rawValue)
            for part in parts {
                XCTAssertLessThanOrEqual(part.rules, ContentBlockingSettings.ruleLimit)
                XCTAssertNotNil(Bundle.main.url(forResource: part.resource, withExtension: "deflate"), part.resource)
            }
        }
    }
}
