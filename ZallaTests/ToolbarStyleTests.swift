import XCTest
@testable import Zalla

final class ToolbarStyleTests: XCTestCase {
    func testDefaultRawValues() {
        XCTAssertEqual(ToolbarStyle.classic.rawValue, "Classic")
        XCTAssertEqual(ToolbarStyle.compact.rawValue, "Compact")
        XCTAssertEqual(ToolbarStyle.storageKey, "toolbarStyle")
    }

    func testAddressBarPlacement() {
        XCTAssertEqual(AddressBarPlacement.bottom.rawValue, "Bottom")
        XCTAssertEqual(AddressBarPlacement.top.rawValue, "Top")
        XCTAssertEqual(AddressBarPlacement.storageKey, "addressBarPlacement")
    }

    func testCompactPillTitleForNewTab() {
        XCTAssertEqual(
            CompactAddressChrome.pillTitle(hasPage: false, pageTitle: "", isReaderActive: false),
            "Search or enter a website"
        )
    }

    func testCompactPillTitleForLoadedPage() {
        XCTAssertEqual(
            CompactAddressChrome.pillTitle(hasPage: true, pageTitle: "Example", isReaderActive: false),
            "Example"
        )
        XCTAssertEqual(
            CompactAddressChrome.pillTitle(hasPage: true, pageTitle: "Reader", isReaderActive: true),
            "Reader"
        )
    }

    func testCompactHostSubtitle() {
        let url = URL(string: "https://www.example.com/path")
        XCTAssertEqual(CompactAddressChrome.hostSubtitle(url: url, hasPage: true), "example.com")
        XCTAssertNil(CompactAddressChrome.hostSubtitle(url: url, hasPage: false))
        XCTAssertNil(CompactAddressChrome.hostSubtitle(url: nil, hasPage: true))
    }

    func testCompactEditingPrefill() {
        let url = URL(string: "https://example.com/path?q=1")
        XCTAssertEqual(CompactAddressChrome.editingPrefill(url: url), "https://example.com/path?q=1")
        XCTAssertEqual(CompactAddressChrome.editingPrefill(url: nil), "")
    }

    func testAddressDisplayCollapsedLabel() {
        let url = URL(string: "https://www.apple.com/iphone")
        XCTAssertEqual(AddressDisplay.collapsedLabel(url: url, hasPage: true), "apple.com")
        XCTAssertEqual(AddressDisplay.collapsedLabel(url: nil, hasPage: false), "Search or enter a website")
    }

    func testChromeModeTipKeysAndCopy() {
        XCTAssertEqual(ChromeModeTips.compactSeenKey, "hasSeenCompactModeTip")
        XCTAssertEqual(ChromeModeTips.topBarSeenKey, "hasSeenTopBarPlacementTip")
        XCTAssertEqual(ChromeModeTips.holdRevealSeenKey, "hasSeenHoldRevealTip")
        XCTAssertFalse(ChromeModeTips.compactMessage.contains(String(UnicodeScalar(0x2014)!)))
        XCTAssertFalse(ChromeModeTips.topBarMessage.isEmpty)
        XCTAssertFalse(ChromeModeTips.holdRevealMessage.isEmpty)
    }

    func testConnectionSecurityEvaluate() {
        let https = URL(string: "https://example.com")
        let http = URL(string: "http://example.com")
        XCTAssertEqual(
            ConnectionSecurity.evaluate(url: https, hasPage: true, hasOnlySecureContent: true),
            .secure
        )
        XCTAssertEqual(
            ConnectionSecurity.evaluate(url: https, hasPage: true, hasOnlySecureContent: false),
            .notSecure
        )
        XCTAssertEqual(
            ConnectionSecurity.evaluate(url: http, hasPage: true, hasOnlySecureContent: true),
            .notSecure
        )
        XCTAssertEqual(
            ConnectionSecurity.evaluate(url: https, hasPage: false, hasOnlySecureContent: true),
            .none
        )
        XCTAssertEqual(
            ConnectionSecurity.evaluate(url: nil, hasPage: true, hasOnlySecureContent: true),
            .none
        )
        XCTAssertEqual(ConnectionSecurity.secure.accessibilityLabel, "Secure connection")
        XCTAssertEqual(ConnectionSecurity.notSecure.accessibilityLabel, "Not Secure")
        XCTAssertNil(ConnectionSecurity.none.accessibilityLabel)
    }
}
