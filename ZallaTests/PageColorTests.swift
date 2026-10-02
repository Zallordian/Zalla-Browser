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
}
