import XCTest
@testable import Zalla

final class ToolbarStyleTests: XCTestCase {
    func testDefaultRawValues() {
        XCTAssertEqual(ToolbarStyle.classic.rawValue, "Classic")
        XCTAssertEqual(ToolbarStyle.compact.rawValue, "Compact")
        XCTAssertEqual(ToolbarStyle.quickAction.rawValue, "Quick Action")
        XCTAssertEqual(ToolbarStyle.storageKey, "toolbarStyle")
    }

    func testToolbarStyleCasesKeepClassicFirst() {
        XCTAssertEqual(ToolbarStyle.allCases, [.classic, .compact, .quickAction])
        XCTAssertEqual(ToolbarStyle(rawValue: "Quick Action"), .quickAction)
        for style in ToolbarStyle.allCases {
            XCTAssertFalse(style.summary.isEmpty)
            XCTAssertFalse(style.symbolName.isEmpty)
            XCTAssertFalse(style.summary.contains(String(UnicodeScalar(0x2014)!)))
        }
    }

    func testQuickActionItemsOrderAndCopy() {
        XCTAssertEqual(QuickActionItem.allCases, [.back, .forward, .tabs, .newTab, .share, .menu])
        XCTAssertEqual(QuickActionItem.newTab.title, "New Tab")
        for item in QuickActionItem.allCases {
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.symbolName.isEmpty)
        }
    }

    func testQuickActionLayoutAnglesSpreadLeftToRight() {
        let angles = QuickActionLayout.angles(count: 6)
        XCTAssertEqual(angles.count, 6)
        XCTAssertEqual(angles.first ?? 0, QuickActionLayout.startAngle, accuracy: 0.001)
        XCTAssertEqual(angles.last ?? 0, QuickActionLayout.endAngle, accuracy: 0.001)
        XCTAssertEqual(QuickActionLayout.angles(count: 1), [90])
        XCTAssertTrue(QuickActionLayout.angles(count: 0).isEmpty)
    }

    func testQuickActionLayoutOpensAwayFromChromeEdge() {
        let count = QuickActionItem.allCases.count
        let bottomFirst = QuickActionLayout.offset(index: 0, count: count, placement: .bottom)
        let bottomLast = QuickActionLayout.offset(index: count - 1, count: count, placement: .bottom)
        XCTAssertLessThan(bottomFirst.width, 0)
        XCTAssertGreaterThan(bottomLast.width, 0)
        XCTAssertLessThan(bottomFirst.height, 0, "Bottom chrome fans upward")

        let topFirst = QuickActionLayout.offset(index: 0, count: count, placement: .top)
        XCTAssertGreaterThan(topFirst.height, 0, "Top chrome fans downward")
        XCTAssertEqual(topFirst.width, bottomFirst.width, accuracy: 0.001)
        XCTAssertEqual(QuickActionLayout.offset(index: 99, count: count, placement: .bottom), .zero)
    }

    func testChromePreviewLayoutReflectsEveryCombination() {
        let classicBottom = ChromePreviewLayout.make(style: .classic, placement: .bottom)
        XCTAssertFalse(classicBottom.addressAtTop)
        XCTAssertTrue(classicBottom.showsNavRow)

        let classicTop = ChromePreviewLayout.make(style: .classic, placement: .top)
        XCTAssertTrue(classicTop.addressAtTop)
        XCTAssertTrue(classicTop.navRowAtBottom)

        let compactTop = ChromePreviewLayout.make(style: .compact, placement: .top)
        XCTAssertTrue(compactTop.addressAtTop)
        XCTAssertTrue(compactTop.showsFloatingRow)
        XCTAssertFalse(compactTop.showsNavRow)

        let quickBottom = ChromePreviewLayout.make(style: .quickAction, placement: .bottom)
        XCTAssertTrue(quickBottom.showsQuickActionButton)
        XCTAssertFalse(quickBottom.showsFloatingRow)
        XCTAssertFalse(quickBottom.addressAtTop)

        let quickTop = ChromePreviewLayout.make(style: .quickAction, placement: .top)
        XCTAssertTrue(quickTop.addressAtTop)
        XCTAssertNotEqual(quickTop, quickBottom)
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
        XCTAssertEqual(ChromeModeTips.quickActionSeenKey, "hasSeenQuickActionTip")
        XCTAssertFalse(ChromeModeTips.quickActionMessage.contains(String(UnicodeScalar(0x2014)!)))
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
