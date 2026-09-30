import XCTest
@testable import Zalla

final class PrivacyReportTests: XCTestCase {
    private func freshDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testClearHostsKeepsTotalsButForgetsSites() {
        let defaults = freshDefaults("zalla.privacyReport.clearHosts")
        PrivacyReport.record(.linkCleaned, host: "www.example.com", in: defaults)
        PrivacyReport.record(.httpsUpgrade, host: "example.org", in: defaults)
        PrivacyReport.clearHosts(in: defaults)
        let store = PrivacyReport.load(from: defaults)
        XCTAssertTrue(store.byHost.isEmpty)
        XCTAssertEqual(store.overall.linkCleaned, 1)
        XCTAssertEqual(store.overall.httpsUpgrade, 1)
        XCTAssertEqual(PrivacyReport.counts(forHost: "example.com", in: defaults), PrivacyReport.Counts())
    }

    func testResetRemovesEverything() {
        let defaults = freshDefaults("zalla.privacyReport.reset")
        PrivacyReport.record(.cookieBannerDismissed, host: "example.com", in: defaults)
        PrivacyReport.reset(in: defaults)
        XCTAssertEqual(PrivacyReport.load(from: defaults), PrivacyReport.Store())
    }
}
