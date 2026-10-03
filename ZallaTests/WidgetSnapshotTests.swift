import XCTest
@testable import Zalla

final class WidgetSnapshotTests: XCTestCase {
    private func item(_ title: String, _ url: String, _ symbol: String = "globe") -> (title: String, urlString: String, symbolName: String) {
        (title, url, symbol)
    }

    func testLinksKeepOnlyWebAddressesWithoutRepeatsAndCapTheList() {
        let list = WidgetShared.links(from: [
            item("Example", "https://example.com/"),
            item("Again", "https://example.com/"),
            item("Mail", "mailto:me@example.com"),
            item("Local", "file:///etc/hosts"),
            item("Script", "javascript:alert(1)"),
            item("", "http://news.example.org/a"),
            item("  Padded  ", " https://padded.example.net ", ""),
            item("Hostless", "https://")
        ])
        XCTAssertEqual(list.map(\.urlString), ["https://example.com/", "http://news.example.org/a", "https://padded.example.net"])
        XCTAssertEqual(list.map(\.title), ["Example", "news.example.org", "Padded"])
        XCTAssertEqual(list.last?.symbolName, "globe")
        let many = (0..<20).map { item("Site \($0)", "https://site\($0).example.com") }
        XCTAssertEqual(WidgetShared.links(from: many).count, WidgetShared.maxLinks)
        XCTAssertEqual(WidgetShared.links(from: many, limit: 4).count, 4)
    }

    func testLongTitlesAreCut() {
        let long = String(repeating: "a", count: 100)
        XCTAssertEqual(WidgetShared.links(from: [item(long, "https://example.com")]).first?.title.count, WidgetShared.maxTitleLength)
    }

    func testOpenLinkRoundTripsThroughTheAppsIncomingLinkRules() {
        let address = "https://example.com/a?x=1&y=2+3#frag"
        let link = WidgetShared.openLink(for: address)
        XCTAssertEqual(link?.scheme, "zalla")
        XCTAssertEqual(link.flatMap { IncomingLink.webURL(from: $0) }?.absoluteString, address)
        XCTAssertNil(WidgetShared.openLink(for: "javascript:alert(1)"))
        XCTAssertNil(WidgetShared.openLink(for: "file:///etc/hosts"))
        XCTAssertNil(WidgetShared.openLink(for: "not a url"))
    }

    func testActionLinksAreTheOnesTheAppRoutes() {
        XCTAssertEqual(WidgetShared.searchLink.flatMap { QuickAction.resolve(url: $0) }, .search)
        XCTAssertEqual(WidgetShared.burnLink.flatMap { QuickAction.resolve(url: $0) }, .burn)
        // The plain open link only opens the app: no action and no web address.
        XCTAssertNil(WidgetShared.appLink.flatMap { QuickAction.resolve(url: $0) })
        XCTAssertNil(WidgetShared.appLink.flatMap { IncomingLink.webURL(from: $0) })
    }

    func testHexParsingAndFallback() {
        XCTAssertEqual(WidgetShared.normalizedHex("#e33b4f"), "E33B4F")
        XCTAssertEqual(WidgetShared.normalizedHex(" 2F6FED "), "2F6FED")
        XCTAssertNil(WidgetShared.normalizedHex("12345"))
        XCTAssertNil(WidgetShared.normalizedHex("GGGGGG"))
        let blue = WidgetShared.rgb(fromHex: "0000FF")
        XCTAssertEqual(blue.blue, 1, accuracy: 0.0001)
        XCTAssertEqual(blue.red, 0, accuracy: 0.0001)
        let fallback = WidgetShared.rgb(fromHex: "nope")
        XCTAssertEqual(fallback.red, Double(0xE3) / 255, accuracy: 0.0001)
    }

    func testAccentFollowsTheAppUnlessAColorIsChosen() {
        var snapshot = WidgetSnapshot()
        snapshot.accentHex = "8B3DDB"
        XCTAssertEqual(WidgetShared.resolvedAccentHex(choiceKey: "followApp", snapshot: snapshot), "8B3DDB")
        XCTAssertEqual(WidgetShared.resolvedAccentHex(choiceKey: "unknown", snapshot: snapshot), "8B3DDB")
        XCTAssertEqual(WidgetShared.resolvedAccentHex(choiceKey: "green", snapshot: snapshot), "2FA866")
        snapshot.accentHex = "oops"
        XCTAssertEqual(WidgetShared.resolvedAccentHex(choiceKey: "followApp", snapshot: snapshot), WidgetShared.defaultAccentHex)
        XCTAssertEqual(Set(WidgetShared.palette.map(\.key)).count, WidgetShared.palette.count)
        for entry in WidgetShared.palette { XCTAssertNotNil(WidgetShared.normalizedHex(entry.hex)) }
    }

    func testFavoriteCountsFollowTheWidgetSize() {
        XCTAssertEqual(WidgetShared.favoriteCount(family: .medium, setting: 8), 4)
        XCTAssertEqual(WidgetShared.favoriteCount(family: .large, setting: 8), 8)
        XCTAssertEqual(WidgetShared.favoriteCount(family: .large, setting: 6), 6)
        XCTAssertEqual(WidgetShared.favoriteCount(family: .medium, setting: 0), 1)
    }

    func testSnapshotSurvivesTheSharedStoreAndSameContentIgnoresTheDate() {
        let defaults = UserDefaults(suiteName: "WidgetSnapshotTests")!
        defaults.removePersistentDomain(forName: "WidgetSnapshotTests")
        XCTAssertFalse(WidgetShared.load(from: defaults).hasData)
        var snapshot = WidgetSnapshot()
        snapshot.accentHex = "2F6FED"
        snapshot.shortcuts = WidgetShared.links(from: [item("Example", "https://example.com")])
        snapshot.privacy = WidgetPrivacyCounts(linkCleaned: 2, httpsUpgrade: 3, cookieBannerDismissed: 4)
        snapshot.updatedAt = Date(timeIntervalSince1970: 1_000)
        WidgetShared.save(snapshot, to: defaults)
        let loaded = WidgetShared.load(from: defaults)
        XCTAssertEqual(loaded, snapshot)
        XCTAssertTrue(loaded.hasData)
        XCTAssertEqual(loaded.privacy.total, 9)
        var later = snapshot
        later.updatedAt = Date(timeIntervalSince1970: 9_999)
        XCTAssertTrue(snapshot.sameContent(as: later))
        later.privacy.linkCleaned += 1
        XCTAssertFalse(snapshot.sameContent(as: later))
        WidgetShared.clear(in: defaults)
        XCTAssertFalse(WidgetShared.load(from: defaults).hasData)
        XCTAssertFalse(WidgetShared.load(from: nil).hasData)
    }

    func testSnapshotCarriesNothingButFavoritesColorAndCounts() {
        let keys = Set(Mirror(reflecting: WidgetSnapshot()).children.compactMap(\.label))
        XCTAssertEqual(keys, ["accentHex", "shortcuts", "bookmarks", "privacy", "updatedAt"])
    }
}
