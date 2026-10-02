import XCTest
@testable import Zalla

final class SettingsCategoryTests: XCTestCase {
    func testEverySectionLivesUnderExactlyOneTab() {
        for section in SettingsSection.allCases {
            let homes = SettingsCategory.allCases.filter { $0.sections.contains(section) }
            XCTAssertEqual(homes, [section.category], "\(section) must be under exactly one tab")
        }
        let listed = SettingsCategory.allCases.flatMap(\.sections)
        XCTAssertEqual(listed.count, SettingsSection.allCases.count)
        XCTAssertEqual(Set(listed.map(\.rawValue)).count, listed.count, "No section is listed twice")
    }

    func testEveryOldSectionIsStillReachable() {
        XCTAssertEqual(SettingsSection.legacy.count, 10)
        XCTAssertEqual(SettingsSection.legacy.map(\.rawValue), [
            "appearance", "accent", "appIcon", "browsing", "tools", "privacy",
            "ourPromise", "supportZalla", "privacyAndSupport", "version"
        ])
        for section in SettingsSection.legacy {
            XCTAssertTrue(SettingsCategory.allCases.contains(section.category))
            XCTAssertTrue(section.category.sections.contains(section))
        }
    }

    func testTabOrderAndGrouping() {
        XCTAssertEqual(SettingsCategory.allCases.map(\.title), ["Appearance", "Privacy", "Browsing", "Tools", "Premium", "About"])
        XCTAssertEqual(SettingsCategory.appearance.sections, [.appearance, .accent, .appIcon])
        XCTAssertEqual(SettingsCategory.privacy.sections, [.privacy])
        XCTAssertEqual(SettingsCategory.browsing.sections, [.browsing])
        XCTAssertEqual(SettingsCategory.tools.sections, [.tools])
        XCTAssertEqual(SettingsCategory.premium.sections, [.unlock, .premiumPrivacy])
        XCTAssertEqual(SettingsCategory.about.sections, [.ourPromise, .supportZalla, .privacyAndSupport, .version])
        for category in SettingsCategory.allCases {
            XCTAssertFalse(category.sections.isEmpty)
            XCTAssertFalse(category.symbolName.isEmpty)
        }
    }

    func testSavedTabFallsBackToAppearance() {
        XCTAssertEqual(SettingsCategory.stored(nil), .appearance)
        XCTAssertEqual(SettingsCategory.stored("nonsense"), .appearance)
        XCTAssertEqual(SettingsCategory.stored("Privacy"), .privacy)
        for category in SettingsCategory.allCases {
            XCTAssertEqual(SettingsCategory.stored(category.rawValue), category)
        }
    }

    func testStepsStopAtTheEnds() {
        XCTAssertNil(SettingsCategory.appearance.adjacent(-1))
        XCTAssertEqual(SettingsCategory.appearance.adjacent(1), .privacy)
        XCTAssertEqual(SettingsCategory.about.adjacent(-1), .premium)
        XCTAssertNil(SettingsCategory.about.adjacent(1))
        XCTAssertEqual(SettingsCategory.tools.adjacent(0), .tools)
    }

    func testTitlesHaveNoDashes() {
        let text = SettingsCategory.allCases.map(\.title)
        XCTAssertFalse(text.contains { $0.contains("\u{2014}") || $0.contains("\u{2013}") })
    }
}
