import XCTest
@testable import Zalla

final class AboutTests: XCTestCase {
    private func scratch(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testChangelogOrderAndContent() {
        XCTAssertEqual(Changelog.releases.first?.version, "Build 31")
        XCTAssertEqual(Changelog.releases.first?.name, "Paperwork")
        XCTAssertEqual(Changelog.releases.dropFirst().first?.version, "Build 30")
        XCTAssertEqual(Changelog.releases.dropFirst().first?.name, "Ready to Type")
        XCTAssertEqual(Changelog.releases.dropFirst(2).first?.version, "Build 29")
        XCTAssertEqual(Changelog.releases.dropFirst(2).first?.name, "Press and Hold")
        XCTAssertEqual(Changelog.releases.dropFirst(3).first?.version, "Build 28")
        XCTAssertEqual(Changelog.releases.dropFirst(3).first?.name, "Smooth Moves")
        XCTAssertEqual(Changelog.releases.dropFirst(4).first?.version, "Build 27")
        XCTAssertEqual(Changelog.releases.dropFirst(4).first?.name, "Seamless Top")
        XCTAssertEqual(Changelog.releases.dropFirst(5).first?.version, "Build 26")
        XCTAssertEqual(Changelog.releases.dropFirst(5).first?.name, "Neon, Frost, Blossom")
        XCTAssertEqual(Changelog.releases.dropFirst(6).first?.version, "Build 25")
        XCTAssertEqual(Changelog.releases.dropFirst(6).first?.name, "One Tap Theme")
        XCTAssertEqual(Changelog.releases.dropFirst(7).first?.version, "Build 24")
        XCTAssertEqual(Changelog.releases.dropFirst(7).first?.name, "Header Room")
        XCTAssertEqual(Changelog.releases.dropFirst(8).first?.version, "Build 23")
        XCTAssertEqual(Changelog.releases.dropFirst(8).first?.name, "Float On")
        XCTAssertEqual(Changelog.releases.dropFirst(9).first?.version, "Build 22")
        XCTAssertEqual(Changelog.releases.dropFirst(9).first?.name, "Edge to Edge")
        XCTAssertEqual(Changelog.releases.dropFirst(10).first?.version, "Build 21")
        XCTAssertEqual(Changelog.releases.dropFirst(10).first?.name, "Settings, Sorted")
        XCTAssertEqual(Changelog.releases.dropFirst(11).first?.version, "Build 20")
        XCTAssertEqual(Changelog.releases.dropFirst(11).first?.name, "One Burn Is Enough")
        XCTAssertEqual(Changelog.releases.dropFirst(12).first?.version, "Build 19")
        XCTAssertEqual(Changelog.releases.dropFirst(12).first?.name, "Pull Down, Burn Up")
        XCTAssertEqual(Changelog.releases.dropFirst(13).first?.version, "Build 18")
        XCTAssertEqual(Changelog.releases.dropFirst(13).first?.name, "Swipe, Sweep, Burn")
        XCTAssertEqual(Changelog.releases.dropFirst(14).first?.version, "Build 17")
        XCTAssertEqual(Changelog.releases.dropFirst(14).first?.name, "Menus that line up")
        XCTAssertEqual(Changelog.releases.dropFirst(15).first?.version, "Build 16")
        XCTAssertEqual(Changelog.releases.dropFirst(15).first?.name, "Where You At")
        XCTAssertEqual(Changelog.releases.dropFirst(16).first?.version, "Build 15")
        XCTAssertEqual(Changelog.releases.dropFirst(17).first?.version, "Build 14")
        XCTAssertEqual(Changelog.releases.last?.version, "1.0")
        XCTAssertEqual(Changelog.releases.last?.name, "Private by Default")
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
