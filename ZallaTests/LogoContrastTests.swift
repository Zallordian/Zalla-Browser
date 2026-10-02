import XCTest
@testable import Zalla

final class LogoContrastTests: XCTestCase {
    private func variant(_ hexes: [String], style: LogoStyle = .auto) -> LogoVariant {
        LogoContrast.variant(style: style, background: LogoContrast.gradientColor(hexes: hexes, fraction: LogoContrast.contentFraction))
    }

    func testContrastMath() {
        let black = LogoRGB(hex: "000000")
        let white = LogoRGB(hex: "FFFFFF")
        XCTAssertEqual(LogoContrast.contrastRatio(black, white), 21, accuracy: 0.01)
        XCTAssertEqual(LogoContrast.contrastRatio(white, white), 1, accuracy: 0.001)
        XCTAssertEqual(LogoContrast.distance(white, white), 0, accuracy: 0.001)
        XCTAssertEqual(LogoContrast.distance(black, white), 1, accuracy: 0.05)
    }

    func testHexParsingFallsBackToZallaRed() {
        XCTAssertEqual(LogoRGB(hex: "#E33B4F"), LogoContrast.zallaRed)
        XCTAssertEqual(LogoRGB(hex: "nonsense"), LogoContrast.zallaRed)
        XCTAssertEqual(LogoRGB(hex: "FF0000"), LogoRGB(r: 1, g: 0, b: 0))
    }

    func testRedAndOrangeWallpapersGetTheWhiteLogo() {
        XCTAssertEqual(variant(["E33B4F", "8F1B31"]), .white, "Crimson")
        XCTAssertEqual(variant(["FF9A5A", "E33B4F", "6E1F5C"]), .white, "Sunset")
        XCTAssertEqual(variant(["F06A2F", "A91F36", "35101B"]), .white, "Ember")
        XCTAssertEqual(variant(["C98555", "5F3421"]), .white, "Copper")
    }

    func testPaleWallpapersThatSwallowRedGetTheBlackLogo() {
        XCTAssertEqual(variant(["FFC2CD", "F27C90"]), .black, "Rose")
    }

    func testWallpapersThatAlreadyContrastKeepTheRedLogo() {
        XCTAssertEqual(variant(["34343B", "121215"]), .red, "Graphite")
        XCTAssertEqual(variant(["FFFFFF", "E9E9F0"]), .red, "Snow")
        XCTAssertEqual(variant(["262B66", "0A0B1E"]), .red, "Midnight")
        XCTAssertEqual(variant(["E4F0D0", "A5C883"]), .red, "Mist is light green, red still reads")
        XCTAssertEqual(variant(["FFE1D0", "FFB3A7"]), .red, "Peach is pale, red still reads")
    }

    func testThePlainBackgroundKeepsTheRedLogoInLightAndDark() {
        for dark in [false, true] {
            for intensity in [0.0, 0.35, 0.6] {
                let bg = LogoContrast.standardBackground(darkMode: dark, accent: LogoContrast.zallaRed, washIntensity: intensity)
                XCTAssertEqual(LogoContrast.variant(style: .auto, background: bg), .red, "dark \(dark) wash \(intensity)")
            }
        }
    }

    func testChosenStylesAlwaysWin() {
        let red = LogoContrast.zallaRed
        XCTAssertEqual(LogoContrast.variant(style: .red, background: red), .red)
        XCTAssertEqual(LogoContrast.variant(style: .white, background: LogoRGB(hex: "FFFFFF")), .white)
        XCTAssertEqual(LogoContrast.variant(style: .black, background: LogoRGB(hex: "000000")), .black)
    }

    func testReadableNeutralPicksTheBetterOne() {
        XCTAssertEqual(LogoContrast.readableNeutral(on: LogoRGB(hex: "101010")), .white)
        XCTAssertEqual(LogoContrast.readableNeutral(on: LogoRGB(hex: "F0F0F0")), .black)
        XCTAssertTrue(LogoContrast.isLightInkBetter(on: LogoRGB(hex: "8F1B31")))
        XCTAssertFalse(LogoContrast.isLightInkBetter(on: LogoRGB(hex: "FF9A5A")), "Bright orange wants dark text")
        XCTAssertTrue(LogoContrast.isLightInkBetter(on: LogoRGB(hex: "E94E51")), "Sunset keeps white text to match the white logo")
    }

    func testPhotoOverlayDarkensAndGradientSamplingBlends() {
        let photo = LogoContrast.photoBackground(average: LogoRGB(r: 1, g: 1, b: 1))
        XCTAssertEqual(photo.r, 0.7, accuracy: 0.001)
        let mid = LogoContrast.gradientColor(hexes: ["000000", "FFFFFF"], fraction: 0.5)
        XCTAssertEqual(mid.g, 0.5, accuracy: 0.001)
        let three = LogoContrast.gradientColor(hexes: ["000000", "FFFFFF", "000000"], fraction: 0.5)
        XCTAssertEqual(three.r, 1, accuracy: 0.001)
        XCTAssertEqual(LogoContrast.gradientColor(hexes: [], fraction: 0.4), LogoContrast.zallaRed)
    }

    func testResettingTheHomePageBringsBackAutoLogo() {
        let defaults = UserDefaults(suiteName: "LogoContrastTests.reset")!
        defaults.removePersistentDomain(forName: "LogoContrastTests.reset")
        defaults.set(LogoStyle.black.rawValue, forKey: LogoStyle.storageKey)
        HomeShortcuts.resetToDefaults(in: defaults)
        XCTAssertNil(defaults.string(forKey: LogoStyle.storageKey))
    }

    func testEveryAssetNameIsDistinct() {
        let names = [LogoVariant.red, .white, .black].map(\.assetName)
        XCTAssertEqual(Set(names).count, 3)
        XCTAssertEqual(LogoStyle.allCases.map(\.rawValue), ["Auto", "Zalla red", "White", "Black"])
    }
}
