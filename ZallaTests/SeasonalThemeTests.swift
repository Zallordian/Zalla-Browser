import XCTest
@testable import Zalla

/// Build 47: free seasonal themes and the Pro accents with their icons.
final class SeasonalThemeTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> SeasonDay { SeasonDay(year: y, month: m, day: d) }

    func testEasterComputus() {
        XCTAssertEqual(HolidayMath.easter(2024), day(2024, 3, 31))
        XCTAssertEqual(HolidayMath.easter(2025), day(2025, 4, 20))
        XCTAssertEqual(HolidayMath.easter(2026), day(2026, 4, 5))
        XCTAssertEqual(HolidayMath.easter(2027), day(2027, 3, 28))
        XCTAssertEqual(HolidayMath.easter(2028), day(2028, 4, 16))
        XCTAssertEqual(HolidayMath.easter(2038), day(2038, 4, 25))
        XCTAssertEqual(HolidayMath.easter(2285), day(2285, 3, 22))
    }

    func testThanksgivingAndMemorialDay() {
        XCTAssertEqual(HolidayMath.thanksgiving(2024), day(2024, 11, 28))
        XCTAssertEqual(HolidayMath.thanksgiving(2025), day(2025, 11, 27))
        XCTAssertEqual(HolidayMath.thanksgiving(2026), day(2026, 11, 26))
        XCTAssertEqual(HolidayMath.thanksgiving(2029), day(2029, 11, 22))
        XCTAssertEqual(HolidayMath.memorialDay(2025), day(2025, 5, 26))
        XCTAssertEqual(HolidayMath.memorialDay(2026), day(2026, 5, 25))
        XCTAssertEqual(HolidayMath.memorialDay(2027), day(2027, 5, 31))
    }

    func testWeekdayAndDayMath() {
        XCTAssertEqual(day(2026, 10, 24).weekday, 6)
        XCTAssertEqual(day(2024, 2, 28).adding(days: 1), day(2024, 2, 29))
        XCTAssertEqual(day(2025, 12, 31).adding(days: 1), day(2026, 1, 1))
        XCTAssertEqual(day(2026, 3, 1).adding(days: -1), day(2026, 2, 28))
    }

    func testBoundaries() {
        XCTAssertTrue(SeasonalWindows.isAvailable(.halloween, on: day(2026, 10, 1)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.halloween, on: day(2026, 11, 1)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.halloween, on: day(2026, 9, 30)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.halloween, on: day(2026, 11, 2)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.christmas, on: day(2026, 12, 26)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.christmas, on: day(2026, 12, 27)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.newYear, on: day(2026, 12, 26)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.newYear, on: day(2027, 1, 7)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.newYear, on: day(2027, 1, 8)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.newYear, on: day(2026, 12, 25)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.winter, on: day(2028, 2, 29)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.winter, on: day(2027, 3, 1)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.fourthOfJuly, on: day(2026, 6, 24)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.fourthOfJuly, on: day(2026, 7, 7)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.fourthOfJuly, on: day(2026, 7, 8)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.harvest, on: day(2026, 11, 26)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.harvest, on: day(2026, 12, 1)))
        // Easter 2026 is April 5: March 22 through April 6.
        XCTAssertTrue(SeasonalWindows.isAvailable(.easter, on: day(2026, 3, 22)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.easter, on: day(2026, 4, 6)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.easter, on: day(2026, 3, 21)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.easter, on: day(2026, 4, 7)))
        // Memorial Day 2026 is May 25: May 16 through May 25.
        XCTAssertTrue(SeasonalWindows.isAvailable(.memorialDay, on: day(2026, 5, 16)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.memorialDay, on: day(2026, 5, 26)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.valentines, on: day(2026, 2, 14)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.stPatricks, on: day(2026, 3, 17)))
        XCTAssertTrue(SeasonalWindows.isAvailable(.summer, on: day(2026, 8, 31)))
        XCTAssertFalse(SeasonalWindows.isAvailable(.summer, on: day(2026, 9, 1)))
    }

    func testNonSeasonalThemesHaveNoWindowAndAlwaysPick() {
        for id in ZallaThemeID.allCases where !id.isSeasonal {
            XCTAssertNil(SeasonalWindows.window(for: id, endingIn: 2026), id.rawValue)
            XCTAssertTrue(SeasonalWindows.canPick(id, on: day(2026, 6, 1)))
        }
        for id in ZallaThemeID.seasonal {
            XCTAssertNotNil(SeasonalWindows.window(for: id, endingIn: 2026), id.rawValue)
            XCTAssertFalse(id.requiresUnlock, "Seasonal themes are free")
        }
    }

    func testEveryDayHasSomethingInSeasonExceptMaybeSeptember() {
        var d = day(2026, 1, 1)
        while d.year == 2026 {
            if d.month != 9 { XCTAssertFalse(SeasonalWindows.available(on: d).isEmpty, d.description) }
            d = d.adding(days: 1)
        }
    }

    func testOutOfSeasonFallback() {
        let june = day(2026, 6, 10)
        XCTAssertFalse(SeasonalWindows.available(on: june).contains(.christmas))
        let list = SeasonalWindows.pickerList(on: june, chosen: .christmas)
        XCTAssertEqual(list.last, .christmas, "The chosen theme stays visible")
        XCTAssertFalse(SeasonalWindows.canPick(.christmas, on: june))
        XCTAssertEqual(SeasonalWindows.caption(for: .christmas, on: june), "Out of season")
        XCTAssertFalse(SeasonalWindows.pickerList(on: june, chosen: .zallaRed).contains(.christmas))
        XCTAssertEqual(ZallaTheme.theme(forRaw: ZallaThemeID.christmas.rawValue).id, .christmas, "Still applied out of season")
        XCTAssertFalse(AppIconPreference.christmas.canPick(on: june))
        XCTAssertTrue(AppIconPreference.christmas.canPick(on: day(2026, 12, 10)))
        XCTAssertTrue(AppIconPreference.ocean.canPick(on: june))
        XCTAssertEqual(SeasonalWindows.caption(for: .christmas, on: day(2026, 12, 10)), "Available until December 26")
    }

    func testProAndSeasonalIcons() {
        for id in ZallaThemeID.pro {
            XCTAssertTrue(id.requiresUnlock)
            XCTAssertTrue(id.suggestedAppIcon.requiresUnlock)
            XCTAssertTrue(ZallaThemeID.featured.contains(id))
        }
        for id in ZallaThemeID.seasonal {
            XCTAssertFalse(id.suggestedAppIcon.requiresUnlock)
            XCTAssertEqual(id.suggestedAppIcon.seasonalTheme, id)
            XCTAssertFalse(ZallaThemeID.featured.contains(id))
        }
        for id in ZallaThemeID.pro + ZallaThemeID.seasonal {
            let icon = id.suggestedAppIcon
            XCTAssertFalse(icon.rawValue.contains(" "))
            XCTAssertEqual(icon.alternateIconName, "AppIcon\(icon.rawValue)")
            XCTAssertEqual(icon.displayName, id.displayName)
        }
    }

    func testNamesHaveNoDashes() {
        let names = (ZallaThemeID.pro + ZallaThemeID.seasonal).map(\.displayName)
            + ZallaThemeID.seasonal.map { SeasonalWindows.caption(for: $0, on: day(2026, 12, 1)) }
        for name in names {
            XCTAssertFalse(name.contains("\u{2014}") || name.contains("\u{2013}"), name)
        }
    }
}
