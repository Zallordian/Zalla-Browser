import XCTest
@testable import Zalla

final class WebsiteLocationTests: XCTestCase {
    private func scratch(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testDefaultIsAsk() {
        let defaults = scratch("WebsiteLocationTests.default")
        XCTAssertEqual(WebsiteLocation.mode(defaults), .ask)
        defaults.set("nonsense", forKey: WebsiteLocation.modeKey)
        XCTAssertEqual(WebsiteLocation.mode(defaults), .ask, "Unknown values fall back to Ask")
    }

    func testModeRoundTrip() {
        let defaults = scratch("WebsiteLocationTests.mode")
        WebsiteLocation.setMode(.never, defaults)
        XCTAssertEqual(WebsiteLocation.mode(defaults), .never)
        WebsiteLocation.setMode(.ask, defaults)
        XCTAssertEqual(WebsiteLocation.mode(defaults), .ask)
        XCTAssertNil(defaults.object(forKey: WebsiteLocation.modeKey), "Ask is stored as no value")
    }

    func testNeverDeniesWithoutAsking() {
        for isPrivate in [false, true] {
            for remembered in [nil, true, false] as [Bool?] {
                XCTAssertEqual(
                    WebsiteLocation.verdict(mode: .never, isPrivate: isPrivate, remembered: remembered), .deny,
                    "Never beats private tabs and any remembered answer"
                )
            }
        }
    }

    func testAskUsesRememberedAnswersOnlyInNormalTabs() {
        XCTAssertEqual(WebsiteLocation.verdict(mode: .ask, isPrivate: false, remembered: nil), .ask)
        XCTAssertEqual(WebsiteLocation.verdict(mode: .ask, isPrivate: false, remembered: true), .allow)
        XCTAssertEqual(WebsiteLocation.verdict(mode: .ask, isPrivate: false, remembered: false), .deny)
        for remembered in [nil, true, false] as [Bool?] {
            XCTAssertEqual(
                WebsiteLocation.verdict(mode: .ask, isPrivate: true, remembered: remembered), .ask,
                "Private tabs ask every time"
            )
        }
    }

    func testAnswersArePerSiteAndSorted() {
        let defaults = scratch("WebsiteLocationTests.answers")
        XCTAssertNil(LocationSettings.answer(forHost: "a.test", defaults))
        LocationSettings.remember(true, host: "b.test", isPrivate: false, defaults)
        LocationSettings.remember(false, host: "a.test", isPrivate: false, defaults)
        XCTAssertEqual(LocationSettings.answer(forHost: "b.test", defaults), true)
        XCTAssertEqual(LocationSettings.answer(forHost: "a.test", defaults), false)
        XCTAssertNil(LocationSettings.answer(forHost: "c.test", defaults))
        XCTAssertEqual(LocationSettings.answers(defaults).map(\.host), ["a.test", "b.test"])
        LocationSettings.forget(host: "a.test", defaults)
        XCTAssertNil(LocationSettings.answer(forHost: "a.test", defaults))
        LocationSettings.forget(host: "b.test", defaults)
        XCTAssertNil(defaults.object(forKey: LocationSettings.answersKey), "An empty list is removed")
    }

    func testPrivateTabsNeverRememberAnything() {
        let defaults = scratch("WebsiteLocationTests.private")
        LocationSettings.remember(true, host: "a.test", isPrivate: true, defaults)
        LocationSettings.remember(false, host: "b.test", isPrivate: true, defaults)
        XCTAssertTrue(LocationSettings.answers(defaults).isEmpty)
        XCTAssertNil(defaults.object(forKey: LocationSettings.answersKey))
    }

    func testSiteKeyMatchesOtherPerSiteSettings() {
        XCTAssertEqual(LocationSettings.siteKey(forHost: "WWW.Example.com"), "example.com")
        XCTAssertEqual(LocationSettings.siteKey(forHost: "maps.example.com."), "maps.example.com")
        XCTAssertNil(LocationSettings.siteKey(forHost: ""))
        XCTAssertNil(LocationSettings.siteKey(forHost: nil))
        XCTAssertEqual(
            LocationSettings.siteKey(forHost: "www.example.com"),
            ContentBlockingSettings.hostKey(for: URL(string: "https://www.example.com/a"))
        )
    }

    func testForgetAnswersKeepsApproximateSharingAndCity() {
        let defaults = scratch("WebsiteLocationTests.forget")
        LocationSettings.save(city: "Austin", latitude: 30.27, longitude: -97.74, defaults)
        LocationSettings.setShared(true, withHost: "a.test", defaults)
        LocationSettings.remember(true, host: "a.test", isPrivate: false, defaults)
        LocationSettings.forgetAnswers(defaults)
        XCTAssertTrue(LocationSettings.answers(defaults).isEmpty)
        XCTAssertTrue(LocationSettings.isShared(withHost: "a.test", defaults))
        XCTAssertEqual(LocationSettings.city(defaults), "Austin")
    }

    func testClearSiteChoicesForBurnItAll() {
        let defaults = scratch("WebsiteLocationTests.burn")
        LocationSettings.save(city: "Austin", latitude: 30.27, longitude: -97.74, defaults)
        LocationSettings.setShared(true, withHost: "a.test", defaults)
        LocationSettings.remember(true, host: "a.test", isPrivate: false, defaults)
        WebsiteLocation.setMode(.never, defaults)
        LocationSettings.clearSiteChoices(defaults)
        XCTAssertTrue(LocationSettings.answers(defaults).isEmpty)
        XCTAssertFalse(LocationSettings.isShared(withHost: "a.test", defaults))
        XCTAssertEqual(LocationSettings.city(defaults), "Austin", "Burn It All keeps settings, only site choices go")
        XCTAssertEqual(WebsiteLocation.mode(defaults), .never)
    }

    func testResetPutsEverythingBack() {
        let defaults = scratch("WebsiteLocationTests.reset")
        WebsiteLocation.setMode(.never, defaults)
        LocationSettings.setShared(true, withHost: "a.test", defaults)
        LocationSettings.remember(false, host: "b.test", isPrivate: false, defaults)
        WebsiteLocation.resetSettings(defaults)
        XCTAssertEqual(WebsiteLocation.mode(defaults), .ask)
        XCTAssertTrue(LocationSettings.sites(defaults).isEmpty)
        XCTAssertTrue(LocationSettings.answers(defaults).isEmpty)
    }

    func testBlocksInPageFollowsVerdict() {
        let defaults = scratch("WebsiteLocationTests.blocks")
        XCTAssertFalse(WebsiteLocation.blocksInPage(host: "a.test", isPrivate: false, defaults))
        LocationSettings.remember(false, host: "a.test", isPrivate: false, defaults)
        XCTAssertTrue(WebsiteLocation.blocksInPage(host: "a.test", isPrivate: false, defaults))
        XCTAssertFalse(WebsiteLocation.blocksInPage(host: "a.test", isPrivate: true, defaults), "Private tabs ignore saved answers")
        XCTAssertFalse(WebsiteLocation.blocksInPage(host: "b.test", isPrivate: false, defaults))
        WebsiteLocation.setMode(.never, defaults)
        XCTAssertTrue(WebsiteLocation.blocksInPage(host: "b.test", isPrivate: false, defaults))
        XCTAssertTrue(WebsiteLocation.blocksInPage(host: "b.test", isPrivate: true, defaults))
    }

    func testPageScriptPlanBlocksOnlyWhenNeeded() {
        let defaults = scratch("WebsiteLocationTests.plan")
        let page = URL(string: "https://www.example.com/a")
        defaults.set(false, forKey: PrivacyShield.referrerKey)
        XCTAssertTrue(PageScripts.plan(for: page, unlocked: false, defaults: defaults).isEmpty, "Ask adds nothing to the page")

        WebsiteLocation.setMode(.never, defaults)
        var plan = PageScripts.plan(for: page, unlocked: false, defaults: defaults)
        XCTAssertEqual(plan.map(\.source), [PageScripts.blockedLocation])
        XCTAssertTrue(plan[0].atDocumentStart)
        XCTAssertFalse(plan[0].mainFrameOnly, "Frames inside the page are blocked too")
        XCTAssertTrue(PageScripts.plan(for: URL(string: "file:///x"), unlocked: false, defaults: defaults).isEmpty)

        WebsiteLocation.setMode(.ask, defaults)
        LocationSettings.remember(false, host: "example.com", isPrivate: false, defaults)
        plan = PageScripts.plan(for: page, unlocked: false, defaults: defaults)
        XCTAssertEqual(plan.count, 1, "A Don't Allow answer blocks that site")
        plan = PageScripts.plan(for: page, unlocked: false, defaults: defaults, isPrivate: true)
        XCTAssertTrue(plan.isEmpty, "Private tabs ask again")
    }

    func testApproximateLocationWinsOverBlockForThatSite() {
        let defaults = scratch("WebsiteLocationTests.approx")
        let page = URL(string: "https://example.com/")
        defaults.set(false, forKey: PrivacyShield.referrerKey)
        LocationSettings.save(city: "Austin", latitude: 30.27, longitude: -97.74, defaults)
        LocationSettings.setShared(true, withHost: "example.com", defaults)
        WebsiteLocation.setMode(.never, defaults)
        let plan = PageScripts.plan(for: page, unlocked: false, defaults: defaults)
        XCTAssertEqual(plan.count, 1, "One geolocation script per page, never two fighting over navigator.geolocation")
        XCTAssertFalse(plan[0].source == PageScripts.blockedLocation)
    }

    func testBlockedScriptReportsPermissionDenied() {
        let script = PageScripts.blockedLocation
        XCTAssertTrue(script.contains("code: 1"))
        XCTAssertTrue(script.contains("getCurrentPosition"))
        XCTAssertTrue(script.contains("watchPosition"))
        XCTAssertTrue(script.contains("state: 'denied'"))
        XCTAssertFalse(script.contains("state: 'granted'"))
    }

    func testCopyHasNoEmDashesEnDashesOrVPNClaims() {
        let copy = [
            WebsiteLocation.Copy.allowTitle, WebsiteLocation.Copy.denyTitle,
            WebsiteLocation.Copy.askDetail, WebsiteLocation.Copy.neverDetail,
            WebsiteLocation.Copy.rememberedMessage, WebsiteLocation.Copy.privateMessage,
            WebsiteLocation.Copy.settingsFooter, WebsiteLocation.Copy.answersFooter,
            WebsiteLocation.Copy.title(site: "a.test"),
            WebsiteLocation.Copy.message(isPrivate: true), WebsiteLocation.Copy.message(isPrivate: false)
        ] + WebsiteLocationMode.allCases.flatMap { [$0.title, $0.detail] }
        XCTAssertFalse(copy.contains { $0.contains("\u{2014}") || $0.contains("\u{2013}") })
        XCTAssertFalse(copy.contains { $0.localizedCaseInsensitiveContains("vpn") })
        XCTAssertEqual(WebsiteLocation.Copy.title(site: "weather.test"), "Allow weather.test to use your location?")
        XCTAssertTrue(WebsiteLocation.Copy.message(isPrivate: true).contains("remember nothing"))
        XCTAssertTrue(WebsiteLocation.Copy.message(isPrivate: false).contains("never to Zalla"))
    }

    func testModes() {
        XCTAssertEqual(WebsiteLocationMode.allCases.map(\.title), ["Ask", "Never"])
        XCTAssertEqual(WebsiteLocationMode.allCases.map(\.rawValue), ["ask", "never"])
    }
}
