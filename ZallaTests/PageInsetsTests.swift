import XCTest
import UIKit
@testable import Zalla

/// Build 54: a site's fixed header (bambulab.com's hamburger) must never sit under the status bar or the top chrome,
/// in any layout, whether or not the site asks for `viewport-fit=cover`.
final class PageInsetsTests: XCTestCase {
    /// iPhone 17 style safe area: status bar on top, home indicator at the bottom.
    private let device = UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)

    func testResolveAddsSafeAreaToChrome() {
        let chrome = UIEdgeInsets(top: 52, left: 0, bottom: 60, right: 0)
        XCTAssertEqual(PageInsets.resolve(chrome: chrome, safeArea: device), UIEdgeInsets(top: 114, left: 0, bottom: 94, right: 0))
    }

    func testResolveNeverGoesNegative() {
        let chrome = UIEdgeInsets(top: -4, left: -1, bottom: -2, right: -3)
        let safe = UIEdgeInsets(top: -1, left: -1, bottom: -1, right: -1)
        XCTAssertEqual(PageInsets.resolve(chrome: chrome, safeArea: safe), .zero)
    }

    func testLandscapeSidesAreCovered() {
        let landscape = UIEdgeInsets(top: 0, left: 62, bottom: 21, right: 62)
        let insets = PageInsets.resolve(chrome: UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0), safeArea: landscape)
        XCTAssertEqual(insets.left, 62)
        XCTAssertEqual(insets.right, 62)
        XCTAssertEqual(insets.bottom, 71)
    }

    func testFrameStartsBelowStatusBarWithStripOrOlderSystems() {
        XCTAssertTrue(PageInsets.frameStartsBelowStatusBar(stripPainted: true, obscuredInsetsSupported: true))
        XCTAssertTrue(PageInsets.frameStartsBelowStatusBar(stripPainted: false, obscuredInsetsSupported: false))
        XCTAssertFalse(PageInsets.frameStartsBelowStatusBar(stripPainted: false, obscuredInsetsSupported: true))
    }

    /// Every preset, both bar positions, immersive and solid, the under status bar setting on and off: the screen
    /// position where a `position: fixed; top: 0` element lands is never above the bottom of the status bar plus
    /// whatever top chrome is drawn over the page.
    func testFixedHeaderClearsStatusBarAndTopChromeInEveryLayout() {
        for preset in LayoutPreset.allCases {
            for placement in AddressBarPlacement.allCases {
                let settings = preset.settings(placement: placement)
                for immersive in [true, false] {
                    for underOn in [true, false] {
                        for supported in [true, false] {
                            let label = "\(preset) \(settings.placement) immersive=\(immersive) under=\(underOn) iOS26=\(supported)"
                            let under = ScrollChrome.pageUnderStatusBar(
                                enabled: underOn,
                                immersive: immersive,
                                bottomBar: settings.placement == .bottom,
                                supported: supported
                            )
                            let plan = PageColor.plan(
                                immersive: immersive, matchPage: true, hasPage: true,
                                sample: PageRGB(red: 0, green: 0, blue: 0), appearance: "System",
                                underStatusBar: under
                            )
                            let startsBelow = PageInsets.frameStartsBelowStatusBar(
                                stripPainted: plan.startsBelowStatusBar,
                                obscuredInsetsSupported: supported
                            )
                            // Measured top chrome: a top address bar when the bar is on top, nothing otherwise.
                            let topChrome: CGFloat = settings.placement == .top ? 52 : 0
                            let chrome = UIEdgeInsets(top: topChrome, left: 0, bottom: settings.placement == .bottom ? 60 : 44, right: 0)
                            let frameTop: CGFloat = startsBelow ? device.top : 0
                            let safe = PageInsets.webViewSafeArea(device: device, frameStartsBelowStatusBar: startsBelow)
                            let insets = PageInsets.resolve(chrome: chrome, safeArea: safe)
                            if supported {
                                // iOS 26+: obscuredContentInsets = insets, so fixed top: 0 lands at frameTop + insets.top.
                                XCTAssertGreaterThanOrEqual(frameTop + insets.top, device.top + topChrome, label)
                            } else {
                                // Before iOS 26 the frame itself never reaches under the clock.
                                XCTAssertGreaterThanOrEqual(frameTop, device.top, label)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Kurt's case: Safari style bar at the bottom, page under a transparent status bar. The page still runs under
    /// the clock (frame starts at 0) but its fixed header starts right below the status bar.
    func testBottomBarUnderStatusBarKeepsTopTransparentAndHeaderTappable() {
        let startsBelow = PageInsets.frameStartsBelowStatusBar(stripPainted: false, obscuredInsetsSupported: true)
        XCTAssertFalse(startsBelow, "The page still draws under the transparent status bar")
        let safe = PageInsets.webViewSafeArea(device: device, frameStartsBelowStatusBar: startsBelow)
        let insets = PageInsets.resolve(chrome: UIEdgeInsets(top: 0, left: 0, bottom: 60, right: 0), safeArea: safe)
        XCTAssertEqual(insets.top, 62)
        XCTAssertEqual(insets.bottom, 94)
    }

    @MainActor
    func testTabsUseTheInsetAwareWebView() {
        let tab = BrowserTab(isPrivate: true)
        XCTAssertTrue(tab.webView is ZallaWebView)
    }
}
