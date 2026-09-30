import XCTest
@testable import Zalla

final class PrivacyShieldTests: XCTestCase {
    private func cleaned(_ text: String) -> String? {
        TrackingParameters.cleaned(URL(string: text)!)?.absoluteString
    }

    func testTrackingParametersAreRemovedAndOthersKept() {
        XCTAssertEqual(cleaned("https://a.test/p?utm_source=x&id=5&fbclid=abc"), "https://a.test/p?id=5")
        XCTAssertEqual(cleaned("https://a.test/p?UTM_MEDIUM=y&gclid=1"), "https://a.test/p")
        XCTAssertEqual(cleaned("https://a.test/p?q=a%20b&mc_eid=1#frag"), "https://a.test/p?q=a%20b#frag")
        XCTAssertNil(cleaned("https://a.test/p?id=5"))
        XCTAssertNil(cleaned("https://a.test/p"))
        XCTAssertNil(cleaned("https://a.test/?q=utm_source"), "Only parameter names count")
        XCTAssertNil(cleaned("mailto:someone@a.test?utm_source=1"))
    }

    func testDefaultsAreSafe() {
        let defaults = UserDefaults(suiteName: "zalla.shield.defaults")!
        defaults.removePersistentDomain(forName: "zalla.shield.defaults")
        XCTAssertTrue(PrivacyShield.stripLinks(defaults))
        XCTAssertTrue(PrivacyShield.trimReferrer(defaults))
        XCTAssertFalse(PrivacyShield.fingerprintProtection(defaults))
        XCTAssertFalse(PrivacyShield.encryptedDNS(defaults))
        XCTAssertNil(ProxySettings.stored(in: defaults))
    }

    func testProxyValidation() {
        XCTAssertEqual(
            ProxySettings.validated(kind: .http, host: " proxy.example.com ", port: "8080"),
            ProxySettings(kind: .http, host: "proxy.example.com", port: 8080)
        )
        XCTAssertNil(ProxySettings.validated(kind: .http, host: "http://proxy.example.com", port: "80"))
        XCTAssertNil(ProxySettings.validated(kind: .socks, host: "proxy.example.com", port: "0"))
        XCTAssertNil(ProxySettings.validated(kind: .socks, host: "proxy.example.com", port: "70000"))
        XCTAssertNil(ProxySettings.validated(kind: .socks, host: "", port: "1080"))

        let defaults = UserDefaults(suiteName: "zalla.shield.proxy")!
        defaults.removePersistentDomain(forName: "zalla.shield.proxy")
        defaults.set(true, forKey: PrivacyShield.proxyEnabledKey)
        defaults.set("SOCKS5", forKey: PrivacyShield.proxyTypeKey)
        defaults.set("10.0.0.2", forKey: PrivacyShield.proxyHostKey)
        defaults.set("1080", forKey: PrivacyShield.proxyPortKey)
        XCTAssertEqual(ProxySettings.stored(in: defaults), ProxySettings(kind: .socks, host: "10.0.0.2", port: 1080))
        PrivacyShield.resetSettings(in: defaults)
        XCTAssertNil(ProxySettings.stored(in: defaults))
    }

    func testCopyIsHonestAndAvoidsForbiddenWords() {
        let copy = [
            PrivacyShield.Copy.stripLinksDetail, PrivacyShield.Copy.referrerDetail,
            PrivacyShield.Copy.fingerprintDetail, PrivacyShield.Copy.encryptedDNSDetail,
            PrivacyShield.Copy.proxyDetail, PrivacyShield.Copy.footer
        ]
        XCTAssertFalse(copy.contains { $0.contains("\u{2014}") })
        XCTAssertTrue(PrivacyShield.Copy.footer.contains("not a VPN"))
        for line in copy.dropLast() {
            XCTAssertFalse(line.contains("VPN"))
        }
        XCTAssertTrue(PrivacyShield.Copy.encryptedDNSDetail.contains("does not let an app change"))
    }

    func testPageScriptPlan() {
        let defaults = UserDefaults(suiteName: "zalla.shield.plan")!
        defaults.removePersistentDomain(forName: "zalla.shield.plan")
        let page = URL(string: "https://www.example.com/a")

        var plan = PageScripts.plan(for: page, unlocked: false, defaults: defaults)
        XCTAssertEqual(plan.count, 1, "Only referrer trimming is on by default")
        XCTAssertTrue(PageScripts.plan(for: URL(string: "file:///x"), unlocked: true, defaults: defaults).isEmpty)
        XCTAssertTrue(PageScripts.plan(for: nil, unlocked: true, defaults: defaults).isEmpty)

        defaults.set(true, forKey: PrivacyShield.fingerprintKey)
        LocationSettings.save(city: "Austin", latitude: 30.27, longitude: -97.74, defaults)
        LocationSettings.setShared(true, withHost: "example.com", defaults)
        SiteCSS.set("body { color: red; }", forHost: "example.com", in: defaults)
        plan = PageScripts.plan(for: page, unlocked: false, defaults: defaults)
        XCTAssertEqual(plan.count, 3, "Referrer, fingerprint, location; site CSS needs Zalla Unlock")
        plan = PageScripts.plan(for: page, unlocked: true, defaults: defaults)
        XCTAssertEqual(plan.count, 4)
        XCTAssertTrue(plan.last?.source.contains("body { color: red; }") == true)
        XCTAssertTrue(PageScripts.plan(for: URL(string: "https://other.test/"), unlocked: true, defaults: defaults).count == 2)

        defaults.set(false, forKey: PrivacyShield.referrerKey)
        XCTAssertEqual(PageScripts.plan(for: page, unlocked: true, defaults: defaults).count, 3)
    }

    func testJavaScriptStringEscaping() {
        XCTAssertEqual(PageScripts.jsString("a\"b"), "\"a\\\"b\"")
        XCTAssertEqual(PageScripts.jsString("line\nbreak"), "\"line\\nbreak\"")
    }
}

final class LocationSettingsTests: XCTestCase {
    func testLocalSearchAddsTheCityOnlyForLocalQueries() {
        XCTAssertEqual(LocalSearch.augmented("pizza near me", city: "Austin"), "pizza in Austin")
        XCTAssertEqual(LocalSearch.augmented("best coffee", city: "Austin"), "best coffee Austin")
        XCTAssertEqual(LocalSearch.augmented("coffee austin", city: "Austin"), "coffee austin")
        XCTAssertEqual(LocalSearch.augmented("swift tutorial", city: "Austin"), "swift tutorial")
        XCTAssertEqual(LocalSearch.augmented("pizza", city: nil), "pizza")
        XCTAssertEqual(LocalSearch.augmented("pizza", city: "  "), "pizza")
    }

    func testCityIsOffByDefaultAndPerSite() {
        let defaults = UserDefaults(suiteName: "zalla.location.tests")!
        defaults.removePersistentDomain(forName: "zalla.location.tests")
        XCTAssertFalse(LocationSettings.usesCityInSearch(defaults))
        XCTAssertNil(LocationSettings.coordinate(defaults))
        LocationSettings.save(city: " Austin ", latitude: 30.27, longitude: -97.74, defaults)
        XCTAssertEqual(LocationSettings.city(defaults), "Austin")
        XCTAssertFalse(LocationSettings.usesCityInSearch(defaults), "Needs the switch too")
        defaults.set(true, forKey: LocationSettings.searchKey)
        XCTAssertTrue(LocationSettings.usesCityInSearch(defaults))
        XCTAssertNil(LocationSettings.coordinate(forHost: "a.test", defaults))
        LocationSettings.setShared(true, withHost: "a.test", defaults)
        XCTAssertEqual(LocationSettings.coordinate(forHost: "a.test", defaults)?.latitude ?? 0, 30.27, accuracy: 0.001)
        LocationSettings.setShared(false, withHost: "a.test", defaults)
        XCTAssertNil(LocationSettings.coordinate(forHost: "a.test", defaults))
        LocationSettings.clear(defaults)
        XCTAssertEqual(LocationSettings.city(defaults), "")
    }
}
