import XCTest
@testable import Zalla

final class AppBannerTests: XCTestCase {
    func testParsesIDAndArgument() {
        let parsed = AppBanner.parse(content: "app-id=544007664, app-argument=https://m.youtube.com/watch?v=abc&t=3, affiliate-data=x")
        XCTAssertEqual(parsed?.appID, "544007664")
        XCTAssertEqual(parsed?.argument?.absoluteString, "https://m.youtube.com/watch?v=abc&t=3")
    }

    func testIDOnlyIsFine() {
        let parsed = AppBanner.parse(content: "app-id=310633997")
        XCTAssertEqual(parsed?.appID, "310633997")
        XCTAssertNil(parsed?.argument)
    }

    func testKeysAreCaseAndSpaceTolerant() {
        let parsed = AppBanner.parse(content: "  APP-ID = 12345 ,App-Argument= https://example.com/a ")
        XCTAssertEqual(parsed?.appID, "12345")
        XCTAssertEqual(parsed?.argument?.host, "example.com")
    }

    func testRejectsBadTags() {
        XCTAssertNil(AppBanner.parse(content: nil))
        XCTAssertNil(AppBanner.parse(content: ""))
        XCTAssertNil(AppBanner.parse(content: "app-argument=https://example.com"))
        XCTAssertNil(AppBanner.parse(content: "app-id=abc"))
        XCTAssertNil(AppBanner.parse(content: "app-id=12 34"))
        XCTAssertNil(AppBanner.parse(content: "app-id="))
        XCTAssertNil(AppBanner.parse(content: "app-id=1234567890123456"))
    }

    func testOnlyWebArgumentsAreKept() {
        XCTAssertNil(AppBanner.parse(content: "app-id=1, app-argument=youtube://watch?v=1")?.argument)
        XCTAssertNil(AppBanner.parse(content: "app-id=1, app-argument=javascript:alert(1)")?.argument)
        XCTAssertNil(AppBanner.parse(content: "app-id=1, app-argument=not a url")?.argument)
        XCTAssertNotNil(AppBanner.parse(content: "app-id=1, app-argument=http://example.com/")?.argument)
    }

    func testFieldsKeepEqualsInValuesAndFirstKeyWins() {
        let values = AppBanner.fields(from: "app-id=1, app-argument=https://x.com/?a=b, app-id=2, junk")
        XCTAssertEqual(values["app-id"], "1")
        XCTAssertEqual(values["app-argument"], "https://x.com/?a=b")
        XCTAssertNil(values["junk"])
    }

    func testInfoUsesThePageAndDropsForeignArguments() {
        let page = PageInfo(themeColor: nil, bodyBackground: nil, htmlBackground: nil,
                            banner: "app-id=544007664, app-argument=https://www.youtube.com/watch?v=1", title: "YouTube")
        let url = URL(string: "https://m.youtube.com/watch?v=1")!
        let info = AppBanner.info(from: page, pageURL: url)
        XCTAssertEqual(info?.appName, "YouTube")
        XCTAssertEqual(info?.hostKey, "youtube.com")
        XCTAssertEqual(info?.argument?.host, "www.youtube.com")

        let foreign = PageInfo(themeColor: nil, bodyBackground: nil, htmlBackground: nil,
                               banner: "app-id=1, app-argument=https://evil.example/", title: "Shop")
        XCTAssertNil(AppBanner.info(from: foreign, pageURL: URL(string: "https://shop.test/")!)?.argument)
    }

    func testInfoNeedsATagAndAWebPage() {
        let none = PageInfo(themeColor: nil, bodyBackground: nil, htmlBackground: nil, banner: nil, title: "x")
        XCTAssertNil(AppBanner.info(from: none, pageURL: URL(string: "https://a.com/")!))
        XCTAssertNil(AppBanner.info(from: nil, pageURL: URL(string: "https://a.com/")!))
        let tagged = PageInfo(themeColor: nil, bodyBackground: nil, htmlBackground: nil, banner: "app-id=1", title: "x")
        XCTAssertNil(AppBanner.info(from: tagged, pageURL: nil))
        XCTAssertNil(AppBanner.info(from: tagged, pageURL: URL(string: "ftp://a.com/")!))
        XCTAssertNotNil(AppBanner.info(from: tagged, pageURL: URL(string: "https://a.com/")!))
    }

    func testHostKeysAndSites() {
        XCTAssertEqual(AppBanner.hostKey("WWW.Example.com"), "example.com")
        XCTAssertEqual(AppBanner.hostKey("m.youtube.com"), "youtube.com")
        XCTAssertEqual(AppBanner.hostKey("mobile.twitter.com"), "twitter.com")
        XCTAssertEqual(AppBanner.hostKey("www."), "www.")
        XCTAssertEqual(AppBanner.hostKey(nil), "")
        XCTAssertEqual(AppBanner.siteLabel("a.b.example.com"), "example.com")
        XCTAssertEqual(AppBanner.siteLabel("news.bbc.co.uk"), "bbc.co.uk")
        XCTAssertTrue(AppBanner.sameSite("m.youtube.com", "www.youtube.com"))
        XCTAssertFalse(AppBanner.sameSite("youtube.com", "youtube.org"))
        XCTAssertFalse(AppBanner.sameSite(nil, nil))
    }

    func testAppNames() {
        XCTAssertEqual(AppBanner.appName(title: "YouTube", host: "m.youtube.com"), "YouTube")
        XCTAssertEqual(AppBanner.appName(title: "Funny cats - YouTube", host: "www.youtube.com"), "YouTube")
        XCTAssertEqual(AppBanner.appName(title: "r/aww | reddit", host: "www.reddit.com"), "reddit")
        XCTAssertEqual(AppBanner.appName(title: "Welcome home", host: "www.example.com"), "Example")
        XCTAssertEqual(AppBanner.appName(title: "", host: "news.bbc.co.uk"), "Bbc")
    }

    func testOpenURLPrefersTheArgumentThenThePage() {
        let page = URL(string: "https://example.com/a")!
        let withArg = AppBannerInfo(appID: "1", argument: URL(string: "https://example.com/b")!, appName: "E", hostKey: "example.com")
        XCTAssertEqual(AppBanner.openURL(for: withArg, pageURL: page)?.path, "/b")
        let without = AppBannerInfo(appID: "1", argument: nil, appName: "E", hostKey: "example.com")
        XCTAssertEqual(AppBanner.openURL(for: without, pageURL: page), page)
        XCTAssertNil(AppBanner.openURL(for: without, pageURL: nil))
        XCTAssertNil(AppBanner.openURL(for: without, pageURL: URL(string: "file:///x")!))
    }

    func testDismissalsAreRememberedPerHost() {
        var dismissals = AppBannerDismissals()
        XCTAssertFalse(dismissals.isDismissed("youtube.com"))
        dismissals.dismiss("youtube.com")
        XCTAssertTrue(dismissals.isDismissed("youtube.com"))
        XCTAssertFalse(dismissals.isDismissed("reddit.com"))
        dismissals.dismiss("")
        XCTAssertEqual(dismissals.hosts.count, 1)
        dismissals.reset()
        XCTAssertFalse(dismissals.isDismissed("youtube.com"))
    }

    func testDefaultsOn() {
        XCTAssertEqual(AppBanner.storageKey, "appBanners")
        XCTAssertTrue(AppBanner.isEnabled(nil))
        XCTAssertFalse(AppBanner.isEnabled(false))
    }
}
