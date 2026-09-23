import XCTest
@testable import Zalla

final class ThemeTests: XCTestCase {
    func testAllThemeIDsResolve() {
        for id in ZallaThemeID.allCases {
            let theme = ZallaTheme.theme(for: id)
            XCTAssertEqual(theme.id, id)
        }
    }

    func testUnknownThemeFallsBackToZallaRed() {
        let theme = ZallaTheme.theme(forRaw: "not-a-theme")
        XCTAssertEqual(theme.id, .zallaRed)
    }

    func testDefaultIconClearsAlternateName() {
        XCTAssertNil(AppIconPreference.default.alternateIconName)
        XCTAssertEqual(AppIconPreference.dark.alternateIconName, "AppIconDark")
        XCTAssertEqual(AppIconPreference.tinted.alternateIconName, "AppIconTinted")
    }

    func testSuggestedIconsPerAccent() {
        XCTAssertEqual(ZallaThemeID.zallaRed.suggestedAppIcon, .default)
        XCTAssertEqual(ZallaThemeID.space.suggestedAppIcon, .dark)
        XCTAssertEqual(ZallaThemeID.ocean.suggestedAppIcon, .tinted)
    }

    func testCustomHexNormalization() {
        XCTAssertEqual(ZallaTheme.normalizeHex("#e33b4f"), "E33B4F")
        XCTAssertNil(ZallaTheme.normalizeHex("zzz"))
        XCTAssertEqual(ZallaTheme.hexString(r: 1, g: 0, b: 0), "FF0000")
    }

    func testFeaturedThemesIncludeZallaRed() {
        XCTAssertEqual(ZallaThemeID.featured.first, .zallaRed)
        XCTAssertFalse(ZallaThemeID.secondary.contains(.zallaRed))
    }
}
