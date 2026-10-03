import XCTest
@testable import Zalla

final class PageColorTests: XCTestCase {
    func testHexColors() {
        XCTAssertEqual(PageColor.parse("#000"), PageRGB(red: 0, green: 0, blue: 0))
        XCTAssertEqual(PageColor.parse("#FFFFFF"), PageRGB.white)
        XCTAssertEqual(PageColor.parse("  #0f0f0f "), PageRGB(red: 15.0 / 255, green: 15.0 / 255, blue: 15.0 / 255))
        let withAlpha = PageColor.parse("#ff000080")
        XCTAssertEqual(withAlpha?.red, 1)
        XCTAssertEqual(withAlpha?.alpha ?? 0, 128.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(PageColor.parse("#f00f")?.alpha, 1)
        XCTAssertNil(PageColor.parse("#12"))
        XCTAssertNil(PageColor.parse("#gggggg"))
        XCTAssertNil(PageColor.parse("#12345"))
    }

    func testRGBFunctions() {
        XCTAssertEqual(PageColor.parse("rgb(255, 0, 0)"), PageRGB(red: 1, green: 0, blue: 0))
        XCTAssertEqual(PageColor.parse("rgba(0, 0, 0, 0)")?.alpha, 0)
        XCTAssertEqual(PageColor.parse("rgba(33, 33, 33, 0.5)")?.alpha ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(PageColor.parse("rgb(0 128 255 / 50%)")?.alpha ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(PageColor.parse("rgb(100%, 0%, 0%)"), PageRGB(red: 1, green: 0, blue: 0))
        XCTAssertEqual(PageColor.parse("rgb(999, -5, 0)"), PageRGB(red: 1, green: 0, blue: 0))
        XCTAssertNil(PageColor.parse("rgb(1, 2)"))
        XCTAssertNil(PageColor.parse("rgb(a, b, c)"))
        XCTAssertNil(PageColor.parse("rgb(1, 2, 3"))
        XCTAssertNil(PageColor.parse("hsl(0, 0%, 0%)"))
    }

    func testNamesAndGarbage() {
        XCTAssertEqual(PageColor.parse("White"), PageRGB.white)
        XCTAssertEqual(PageColor.parse("black"), PageRGB.black)
        XCTAssertEqual(PageColor.parse("transparent")?.alpha, 0)
        XCTAssertNil(PageColor.parse("notacolor"))
        XCTAssertNil(PageColor.parse(""))
        XCTAssertNil(PageColor.parse(nil))
    }

    func testLuminanceAndTextChoice() {
        XCTAssertEqual(PageRGB.white.luminance, 1, accuracy: 0.0001)
        XCTAssertEqual(PageRGB.black.luminance, 0, accuracy: 0.0001)
        XCTAssertTrue(PageRGB.black.prefersLightText)
        XCTAssertFalse(PageRGB.white.prefersLightText)
        XCTAssertTrue(PageColor.parse("#0f0f0f")!.prefersLightText, "YouTube dark")
        XCTAssertFalse(PageColor.parse("#f9f9f9")!.prefersLightText)
        XCTAssertTrue(PageColor.parse("#1a1a2e")!.prefersLightText)
    }

    func testSamplePrefersThemeColorThenBodyThenHtml() {
        let theme = PageInfo(themeColor: "#112233", bodyBackground: "rgb(255, 0, 0)", htmlBackground: "rgb(0, 255, 0)", banner: nil, title: "")
        XCTAssertEqual(PageColor.sample(from: theme), PageColor.parse("#112233"))
        let body = PageInfo(themeColor: nil, bodyBackground: "rgb(255, 0, 0)", htmlBackground: "rgb(0, 255, 0)", banner: nil, title: "")
        XCTAssertEqual(PageColor.sample(from: body), PageRGB(red: 1, green: 0, blue: 0))
        let html = PageInfo(themeColor: nil, bodyBackground: "rgba(0, 0, 0, 0)", htmlBackground: "rgb(0, 255, 0)", banner: nil, title: "")
        XCTAssertEqual(PageColor.sample(from: html), PageRGB(red: 0, green: 1, blue: 0))
        let none = PageInfo(themeColor: "garbage", bodyBackground: "rgba(0, 0, 0, 0)", htmlBackground: "transparent", banner: nil, title: "")
        XCTAssertEqual(PageColor.sample(from: none), PageColor.canvas, "A page that paints nothing shows white")
    }

    func testSampleDropsTheAlphaOfAnOpaqueEnoughColor() {
        let info = PageInfo(themeColor: "rgba(10, 20, 30, 0.95)", bodyBackground: nil, htmlBackground: nil, banner: nil, title: "")
        XCTAssertEqual(PageColor.sample(from: info).alpha, 1)
        let faint = PageInfo(themeColor: "rgba(10, 20, 30, 0.4)", bodyBackground: nil, htmlBackground: nil, banner: nil, title: "")
        XCTAssertEqual(PageColor.sample(from: faint), PageColor.canvas)
    }

    func testPageInfoFromMessageBody() {
        let body: [String: Any] = [
            "theme": " #000000 ", "body": "rgb(0, 0, 0)", "html": NSNull(),
            "banner": "app-id=544007664, app-argument=https://youtube.com/", "title": "YouTube"
        ]
        let info = PageInfo.from(body)
        XCTAssertEqual(info?.themeColor, "#000000")
        XCTAssertNil(info?.htmlBackground)
        XCTAssertEqual(info?.banner, "app-id=544007664, app-argument=https://youtube.com/")
        XCTAssertEqual(info?.title, "YouTube")
        XCTAssertNil(PageInfo.from("nope"))
        XCTAssertNil(PageInfo.from(42))
        let empty = PageInfo.from([String: Any]())
        XCTAssertEqual(empty?.title, "")
    }

    func testPlanIsOffOutsideTheImmersivePageCase() {
        let off = PageColor.StatusBarPlan(fill: .none, schemeOverride: nil)
        XCTAssertEqual(PageColor.plan(immersive: false, matchPage: true, hasPage: true, sample: .black, appearance: "System"), off)
        XCTAssertEqual(PageColor.plan(immersive: true, matchPage: true, hasPage: false, sample: .black, appearance: "System"), off)
    }

    func testPlanFallsBackWhenSettingOffOrColorUnknown() {
        let fallback = PageColor.StatusBarPlan(fill: .fallback, schemeOverride: nil)
        XCTAssertEqual(PageColor.plan(immersive: true, matchPage: false, hasPage: true, sample: .black, appearance: "System"), fallback)
        XCTAssertEqual(PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: nil, appearance: "System"), fallback)
    }

    func testPlanFollowsThePageUnderSystemAppearance() {
        let dark = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .black, appearance: "System")
        XCTAssertEqual(dark.fill, .page(.black))
        XCTAssertEqual(dark.schemeOverride, .dark)
        let light = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .white, appearance: "System")
        XCTAssertEqual(light.fill, .page(.white))
        XCTAssertEqual(light.schemeOverride, .light)
    }

    func testPlanRespectsAnExplicitAppearance() {
        let darkPageInDark = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .black, appearance: "Dark")
        XCTAssertEqual(darkPageInDark, PageColor.StatusBarPlan(fill: .page(.black), schemeOverride: nil))
        let lightPageInDark = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .white, appearance: "Dark")
        XCTAssertEqual(lightPageInDark, PageColor.StatusBarPlan(fill: .fallback, schemeOverride: nil))
        let darkPageInLight = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .black, appearance: "Light")
        XCTAssertEqual(darkPageInLight, PageColor.StatusBarPlan(fill: .fallback, schemeOverride: nil))
        let lightPageInLight = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .white, appearance: "Light")
        XCTAssertEqual(lightPageInLight, PageColor.StatusBarPlan(fill: .page(.white), schemeOverride: nil))
    }

    func testSettingDefaultsOn() {
        XCTAssertEqual(PageColor.storageKey, "statusBarMatchesPage")
        XCTAssertTrue(PageColor.isEnabled(nil))
        XCTAssertFalse(PageColor.isEnabled(false))
    }

    func testScriptAsksOnlyForColorsAndTheBannerTag() {
        XCTAssertTrue(PageColor.script.contains("zallaPageInfo"))
        XCTAssertTrue(PageColor.script.contains("theme-color"))
        XCTAssertTrue(PageColor.script.contains("apple-itunes-app"))
        XCTAssertFalse(PageColor.script.contains("fetch("))
        XCTAssertFalse(PageColor.script.contains("XMLHttpRequest"))
        XCTAssertFalse(PageColor.script.contains("\u{2014}"))
    }

    func testWebViewStartsBelowTheStatusBarOnlyWhileAStripIsPainted() {
        func plan(immersive: Bool, match: Bool, page: Bool, sample: PageRGB?) -> PageColor.StatusBarPlan {
            PageColor.plan(immersive: immersive, matchPage: match, hasPage: page, sample: sample, appearance: "System")
        }
        XCTAssertTrue(plan(immersive: true, match: true, page: true, sample: .white).startsBelowStatusBar)
        XCTAssertTrue(plan(immersive: true, match: true, page: true, sample: nil).startsBelowStatusBar, "Fallback strip still pushes the page down")
        XCTAssertTrue(plan(immersive: true, match: false, page: true, sample: .white).startsBelowStatusBar)
        XCTAssertFalse(plan(immersive: false, match: true, page: true, sample: .white).startsBelowStatusBar, "Solid bars: unchanged")
        XCTAssertFalse(plan(immersive: true, match: true, page: false, sample: .white).startsBelowStatusBar, "New tab page keeps its wallpaper")
    }

    func testFrameDoesNotMoveWhenThePageColorArrives() {
        let before = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: nil, appearance: "System")
        let after = PageColor.plan(immersive: true, matchPage: true, hasPage: true, sample: .black, appearance: "System")
        XCTAssertNotEqual(before.fill, after.fill)
        XCTAssertEqual(before.startsBelowStatusBar, after.startsBelowStatusBar)
    }

    // MARK: - Top edge sampling, loading, hysteresis

    private func info(
        edge: String? = nil, theme: String? = nil, body: String? = nil, html: String? = nil, ready: Bool = true
    ) -> PageInfo {
        PageInfo(
            themeColor: theme, bodyBackground: body, htmlBackground: html, banner: nil, title: "",
            edgeBackground: edge, ready: ready
        )
    }

    func testSamplePrefersTheTopEdgeThenThemeThenBodyThenHtmlThenCanvas() {
        let all = info(edge: "rgb(0, 0, 0)", theme: "#111111", body: "#222222", html: "#333333")
        XCTAssertEqual(PageColor.sample(from: all), PageRGB.black)
        let noEdge = info(edge: "rgba(0, 0, 0, 0)", theme: "#ff0000", body: "#222222")
        XCTAssertEqual(PageColor.sample(from: noEdge), PageRGB(red: 1, green: 0, blue: 0))
        XCTAssertEqual(PageColor.sample(from: info(html: "#00ff00")), PageRGB(red: 0, green: 1, blue: 0))
        XCTAssertEqual(PageColor.sample(from: info()), PageColor.canvas)
    }

    func testPageInfoReadsEdgeAndReadyKeys() {
        let full = PageInfo.from(["edge": " rgb(3, 3, 3) ", "ready": false, "title": "x"] as [String: Any])
        XCTAssertEqual(full?.edgeBackground, "rgb(3, 3, 3)")
        XCTAssertEqual(full?.ready, false)
        let bare = PageInfo.from(["title": "x"] as [String: Any])
        XCTAssertNil(bare?.edgeBackground)
        XCTAssertEqual(bare?.ready, true)
    }

    func testWeakSamplesAreIgnoredWhileThePageIsStillLoading() {
        let current = PageRGB(red: 0.1, green: 0.1, blue: 0.1)
        XCTAssertTrue(PageColor.isWeak(info(ready: false)))
        XCTAssertEqual(PageColor.next(current: current, info: info(ready: false)), current)
        XCTAssertNil(PageColor.next(current: nil, info: info(ready: false)))
        // A loaded page that paints nothing really shows the white canvas.
        XCTAssertEqual(PageColor.next(current: current, info: info(ready: true)), PageColor.canvas)
        // A real sample is taken even before the load finishes.
        XCTAssertFalse(PageColor.isWeak(info(theme: "#000000", ready: false)))
        XCTAssertEqual(PageColor.next(current: current, info: info(theme: "#000000", ready: false)), PageRGB.black)
    }

    func testDiffersIgnoresTinyShifts() {
        let a = PageRGB(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertFalse(PageColor.differs(a, PageRGB(red: 0.505, green: 0.5, blue: 0.5)))
        XCTAssertTrue(PageColor.differs(a, PageRGB(red: 0.5, green: 0.52, blue: 0.5)))
        XCTAssertTrue(PageColor.differs(nil, a))
        XCTAssertTrue(PageColor.differs(a, nil))
        XCTAssertFalse(PageColor.differs(nil, nil))
    }

    func testClockTextHasHysteresisNearMidGray() {
        let nearBlack = PageRGB(red: 0.05, green: 0.05, blue: 0.05)
        let nearWhite = PageRGB(red: 0.95, green: 0.95, blue: 0.95)
        // About 0.18 luminance, inside the band between the two limits.
        let mid = PageRGB(red: 0.46, green: 0.46, blue: 0.46)
        XCTAssertGreaterThan(mid.luminance, PageColor.darkBelow)
        XCTAssertLessThan(mid.luminance, PageColor.lightAbove)
        XCTAssertTrue(PageColor.isDark(nearBlack, previous: nil))
        XCTAssertFalse(PageColor.isDark(nearWhite, previous: nil))
        XCTAssertTrue(PageColor.isDark(mid, previous: true))
        XCTAssertFalse(PageColor.isDark(mid, previous: false))
        XCTAssertEqual(PageColor.isDark(mid, previous: nil), mid.prefersLightText)
        XCTAssertTrue(PageColor.isDark(mid, previous: PageColor.isDark(nearBlack, previous: nil)))
    }

    func testPlanUsesTheHysteresisChoiceWhenGiven() {
        let mid = PageRGB(red: 0.46, green: 0.46, blue: 0.46)
        let held = PageColor.plan(
            immersive: true, matchPage: true, hasPage: true, sample: mid, appearance: "System", isDark: true
        )
        XCTAssertEqual(held.schemeOverride, .dark)
        let flipped = PageColor.plan(
            immersive: true, matchPage: true, hasPage: true, sample: mid, appearance: "System", isDark: false
        )
        XCTAssertEqual(flipped.schemeOverride, .light)
    }

    func testScriptLooksAtTheTopEdgeAndStaysQuiet() {
        XCTAssertTrue(PageColor.script.contains("elementFromPoint"))
        XCTAssertTrue(PageColor.script.contains("requestAnimationFrame"))
        XCTAssertTrue(PageColor.script.contains("MutationObserver"))
        XCTAssertTrue(PageColor.script.contains("prefers-color-scheme"))
        XCTAssertTrue(PageColor.script.contains("readyState"))
        XCTAssertFalse(PageColor.script.contains("\u{2013}"))
    }
}
