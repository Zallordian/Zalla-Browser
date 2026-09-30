import XCTest
@testable import Zalla

final class AboutTests: XCTestCase {
    private func scratch(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testChangelogOrderAndContent() {
        XCTAssertEqual(Changelog.releases.first?.version, "1.0")
        XCTAssertEqual(Changelog.releases.first?.name, "Private by Default")
        XCTAssertEqual(Changelog.beta.map(\.version), ["Beta 3", "Beta 2", "Beta 1"])
        XCTAssertEqual(Changelog.beta.map(\.name), ["Make It Yours", "Everyday Polish", "First Look"])
    }

    func testChangelogHasNoEmDashes() {
        let all = (Changelog.releases + Changelog.beta).flatMap { [$0.name, $0.improvements, $0.fixes] + $0.highlights }
        XCTAssertFalse(all.contains { $0.contains("\u{2014}") })
        XCTAssertFalse(AboutLinks.storyPlaceholder.contains("\u{2014}"))
    }

    func testAboutLinks() {
        XCTAssertEqual(AboutLinks.privacy.absoluteString, "https://zalla.gg/privacy")
        XCTAssertEqual(AboutLinks.support.absoluteString, "https://zalla.gg/support")
        XCTAssertEqual(AboutLinks.feedbackEmail, "ZallaBrowser@pm.me")
        XCTAssertEqual(AboutLinks.feedbackURL.scheme, "mailto")
        XCTAssertEqual(AboutLinks.storyPlaceholder, "The story behind Zalla is coming soon.")
    }

    func testSafetyOverviewReflectsSettings() {
        let defaults = scratch("AboutTests.safety")
        var items = SafetyOverview.items(unlocked: false, defaults: defaults)
        func item(_ title: String) -> SafetyItem { items.first { $0.title == title }! }
        XCTAssertEqual(item("Ad and tracker blocking").status, "On")
        XCTAssertEqual(item("HTTPS-Only Mode").status, "Off")
        XCTAssertEqual(item("Face ID for private tabs").status, "Locked")
        XCTAssertEqual(item("Encrypted DNS").status, "Off")
        defaults.set(true, forKey: HTTPSOnly.storageKey)
        defaults.set(true, forKey: PrivacyShield.encryptedDNSKey)
        defaults.set(true, forKey: PrivateTabLock.storageKey)
        items = SafetyOverview.items(unlocked: true, defaults: defaults)
        XCTAssertEqual(item("HTTPS-Only Mode").status, "On")
        XCTAssertEqual(item("Encrypted DNS").status, "On")
        XCTAssertEqual(item("Face ID for private tabs").status, "On")
        XCTAssertEqual(item("Auto-clear").status, "Off")
    }

    func testSafetyOverviewHasNoEmDashesOrVPNClaims() {
        let text = SafetyOverview.items(unlocked: true, defaults: scratch("AboutTests.copy"))
            .flatMap { [$0.title, $0.detail, $0.status] }
        XCTAssertFalse(text.contains { $0.contains("\u{2014}") })
        XCTAssertFalse(text.contains { $0.localizedCaseInsensitiveContains("vpn") })
    }
}
