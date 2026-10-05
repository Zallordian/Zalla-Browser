import XCTest
@testable import Zalla

final class CookieBannerTests: XCTestCase {
    func testOnByDefaultUnlessTurnedOff() {
        let defaults = UserDefaults(suiteName: "zalla.cookieBanner.tests")!
        defaults.removePersistentDomain(forName: "zalla.cookieBanner.tests")
        XCTAssertTrue(CookieBannerDismiss.enabled(in: defaults))
        defaults.set(false, forKey: CookieBannerDismiss.storageKey)
        XCTAssertFalse(CookieBannerDismiss.enabled(in: defaults))
    }

    func testMessageNameMatchesTheScript() {
        XCTAssertEqual(CookieBannerDismiss.messageName, "zallaCookie")
        XCTAssertTrue(CookieBannerDismiss.script.contains("messageHandlers.\(CookieBannerDismiss.messageName)"))
    }

    func testScriptOnlyKnowsRejectWording() {
        let script = CookieBannerDismiss.script.lowercased()
        for phrase in ["reject all", "decline all", "only necessary", "necessary only"] {
            XCTAssertTrue(script.contains("'\(phrase)'"), phrase)
        }
        for accepting in ["accept all", "accept cookies", "allow all", "i agree", "agree and", "'agree'", "consent-all"] {
            XCTAssertFalse(script.contains(accepting), accepting)
        }
    }

    func testBannerCheckIgnoresGenericDialogs() {
        let script = CookieBannerDismiss.script
        XCTAssertFalse(script.contains("truste|dialog"))
        XCTAssertTrue(script.contains("/cookie|consent|gdpr|privacy|cmp|onetrust|didomi|cookiebot|truste/"))
    }

    func testNoSelectorThatCouldPressAccept() {
        XCTAssertFalse(CookieBannerDismiss.script.contains("truste-button2"))
    }

    func testScriptStopsAfterAFewSeconds() {
        XCTAssertTrue(CookieBannerDismiss.script.contains("tries > 12"))
        XCTAssertTrue(CookieBannerDismiss.script.contains("}, 500);"))
        XCTAssertTrue(CookieBannerDismiss.script.contains("window.__zallaCookieBanner"))
    }

    func testScriptHasNoDashesOrNonASCII() {
        XCTAssertTrue(CookieBannerDismiss.script.unicodeScalars.allSatisfy { $0.isASCII })
    }
}
