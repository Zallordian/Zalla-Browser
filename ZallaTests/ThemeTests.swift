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
}
