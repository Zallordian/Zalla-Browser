import XCTest
@testable import Zalla

final class AboutTests: XCTestCase {
    private func scratch(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testChangelogOrderAndContent() {
        // The public release shows one human 1.0 entry. Build history lives in docs/CHANGELOG_HISTORY.md.
        XCTAssertEqual(Changelog.releases.map(\.version), ["1.0"])
        XCTAssertEqual(Changelog.releases.first?.name, "Private by Default")
        XCTAssertTrue(Changelog.beta.isEmpty)
        let text = Changelog.releases.flatMap { $0.highlights + [$0.improvements, $0.fixes] }.joined(separator: " ")
        XCTAssertFalse(text.contains("Build "), "No internal build numbers in user-facing notes")
        XCTAssertFalse(text.lowercased().contains("encrypted dns"), "DNS scope is explained in Settings, not claimed here")
        XCTAssertTrue(text.contains("not a VPN"))
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
        XCTAssertFalse(AboutLinks.showsStory, "The story section stays hidden until real copy exists")
    }

    func testSafetyOverviewReflectsSettings() {
        let defaults = scratch("AboutTests.safety")
        var items = SafetyOverview.items(unlocked: false, defaults: defaults)
        func item(_ title: String) -> SafetyItem { items.first { $0.title == title }! }
        XCTAssertEqual(item("Ad and tracker blocking").status, "On")
        XCTAssertEqual(item("HTTPS-Only Mode").status, "On", "On unless you turn it off")
        XCTAssertEqual(item("Face ID for private tabs").status, "Locked")
        XCTAssertEqual(item("Encrypted DNS").status, "Off")
        XCTAssertEqual(item("Website location").status, "Ask", "Ask unless you choose Never")
        defaults.set(false, forKey: HTTPSOnly.storageKey)
        defaults.set(true, forKey: PrivacyShield.encryptedDNSKey)
        defaults.set(true, forKey: PrivateTabLock.storageKey)
        items = SafetyOverview.items(unlocked: true, defaults: defaults)
        XCTAssertEqual(item("HTTPS-Only Mode").status, "Off")
        XCTAssertEqual(item("Encrypted DNS").status, "On")
        XCTAssertEqual(item("Face ID for private tabs").status, "On")
        XCTAssertEqual(item("Auto-clear").status, "Off")
        WebsiteLocation.setMode(.never, defaults)
        items = SafetyOverview.items(unlocked: true, defaults: defaults)
        XCTAssertEqual(item("Website location").status, "Never")
    }

    func testSafetyOverviewHasNoEmDashesOrVPNClaims() {
        let text = SafetyOverview.items(unlocked: true, defaults: scratch("AboutTests.copy"))
            .flatMap { [$0.title, $0.detail, $0.status] }
        XCTAssertFalse(text.contains { $0.contains("\u{2014}") })
        XCTAssertFalse(text.contains { $0.localizedCaseInsensitiveContains("vpn") })
    }
}
