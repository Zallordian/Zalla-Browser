import Foundation

/// A calendar day with no time or zone, so seasonal windows are pure math and easy to test.
struct SeasonDay: Comparable, Hashable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    static func < (a: SeasonDay, b: SeasonDay) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// The user's local day for a date.
    init(_ date: Date, calendar: Calendar = .current) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: return isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// 0 is Sunday, 1 is Monday, through 6 for Saturday (Sakamoto's method).
    var weekday: Int {
        let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
        let y = month < 3 ? year - 1 : year
        return (y + y / 4 - y / 100 + y / 400 + t[month - 1] + day) % 7
    }

    func adding(days: Int) -> SeasonDay {
        var y = year, m = month, d = day + days
        while d > SeasonDay.daysIn(month: m, year: y) {
            d -= SeasonDay.daysIn(month: m, year: y)
            m += 1
            if m > 12 { m = 1; y += 1 }
        }
        while d < 1 {
            m -= 1
            if m < 1 { m = 12; y -= 1 }
            d += SeasonDay.daysIn(month: m, year: y)
        }
        return SeasonDay(year: y, month: m, day: d)
    }
}

enum HolidayMath {
    /// Western (Gregorian) Easter Sunday, using the anonymous Gregorian computus (Meeus, Jones, Butcher).
    static func easter(_ year: Int) -> SeasonDay {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return SeasonDay(year: year, month: month, day: day)
    }

    /// US Thanksgiving: the fourth Thursday of November.
    static func thanksgiving(_ year: Int) -> SeasonDay {
        let first = SeasonDay(year: year, month: 11, day: 1)
        let offset = (4 - first.weekday + 7) % 7
        return first.adding(days: offset + 21)
    }

    /// US Memorial Day: the last Monday of May.
    static func memorialDay(_ year: Int) -> SeasonDay {
        let last = SeasonDay(year: year, month: 5, day: 31)
        let back = (last.weekday - 1 + 7) % 7
        return last.adding(days: -back)
    }
}

/// When each free seasonal theme can be picked. Windows are inclusive and follow the user's local date.
enum SeasonalWindows {
    /// The window that ends in `year`. New Year's and Winter start in December of the year before.
    static func window(for id: ZallaThemeID, endingIn year: Int) -> ClosedRange<SeasonDay>? {
        let last = year - 1
        func d(_ m: Int, _ day: Int) -> SeasonDay { SeasonDay(year: year, month: m, day: day) }
        func prev(_ m: Int, _ day: Int) -> SeasonDay { SeasonDay(year: last, month: m, day: day) }
        switch id {
        case .newYear: return prev(12, 26)...d(1, 7)
        case .winter: return prev(12, 1)...d(2, SeasonDay.daysIn(month: 2, year: year))
        case .valentines: return d(2, 1)...d(2, 15)
        case .stPatricks: return d(3, 1)...d(3, 18)
        case .easter:
            let sunday = HolidayMath.easter(year)
            return sunday.adding(days: -14)...sunday.adding(days: 1)
        case .spring: return d(3, 19)...d(5, 31)
        case .memorialDay:
            let monday = HolidayMath.memorialDay(year)
            return monday.adding(days: -9)...monday
        case .summer: return d(6, 1)...d(8, 31)
        case .fourthOfJuly: return d(6, 24)...d(7, 7)
        case .halloween: return d(10, 1)...d(11, 1)
        case .harvest: return d(10, 1)...d(11, 30)
        case .christmas: return d(12, 1)...d(12, 26)
        default: return nil
        }
    }

    /// The window that contains `day`, or nil when the theme is out of season (or is not seasonal).
    static func activeWindow(for id: ZallaThemeID, on day: SeasonDay) -> ClosedRange<SeasonDay>? {
        for year in [day.year, day.year + 1] {
            if let window = window(for: id, endingIn: year), window.contains(day) { return window }
        }
        return nil
    }

    static func isAvailable(_ id: ZallaThemeID, on day: SeasonDay) -> Bool {
        activeWindow(for: id, on: day) != nil
    }

    /// Seasonal themes that can be picked today, in calendar order.
    static func available(on day: SeasonDay) -> [ZallaThemeID] {
        ZallaThemeID.seasonal.filter { isAvailable($0, on: day) }
    }

    /// What the Seasonal row shows: everything in season, plus the chosen theme if it went out of season,
    /// so it stays visible (marked Out of season) while it is applied.
    static func pickerList(on day: SeasonDay, chosen: ZallaThemeID?) -> [ZallaThemeID] {
        var list = available(on: day)
        if let chosen, chosen.isSeasonal, !list.contains(chosen) { list.append(chosen) }
        return list
    }

    /// Can a swatch or icon be newly picked today? Non seasonal themes always can (Unlock is checked elsewhere).
    static func canPick(_ id: ZallaThemeID, on day: SeasonDay) -> Bool {
        !id.isSeasonal || isAvailable(id, on: day)
    }

    /// "Available until December 26", or "Out of season".
    static func caption(for id: ZallaThemeID, on day: SeasonDay) -> String {
        guard let window = activeWindow(for: id, on: day) else { return "Out of season" }
        return "Available until \(monthName(window.upperBound.month)) \(window.upperBound.day)"
    }

    static func monthName(_ month: Int) -> String {
        ["January", "February", "March", "April", "May", "June", "July", "August",
         "September", "October", "November", "December"][max(0, min(11, month - 1))]
    }
}

extension AppIconPreference {
    /// The seasonal theme this icon belongs to, if any.
    var seasonalTheme: ZallaThemeID? {
        ZallaThemeID.seasonal.first { $0.suggestedAppIcon == self }
    }

    /// Seasonal icons can be picked only in season. One already in use stays until it is changed.
    func canPick(on day: SeasonDay) -> Bool {
        guard let theme = seasonalTheme else { return true }
        return SeasonalWindows.isAvailable(theme, on: day)
    }
}
