import SwiftUI
import UIKit

enum ZallaThemeID: String, CaseIterable, Identifiable, Codable {
    case zallaRed
    case orange
    case yellow
    case green
    case blue
    case indigo
    case violet
    case ocean
    case forest
    case space
    case jungle
    case volcano
    case deepOcean
    case arcade
    case neonCity
    case arctic
    case cherryBlossom
    // Build 47 Pro accents (Zalla Unlock), each with its own icon.
    case northwoods
    case lakeSuperior
    case midnightEmber
    case aurora
    case oledVoid
    // Build 47 free seasonal themes, pickable only in their window (SeasonalThemes.swift).
    case newYear
    case winter
    case valentines
    case stPatricks
    case easter
    case spring
    case memorialDay
    case summer
    case fourthOfJuly
    case halloween
    case harvest
    case christmas

    var id: String { rawValue }

    /// Jungle and the newer themes arrive with their theme packs, which are part of Zalla Unlock. Older accents stay free.
    var requiresUnlock: Bool {
        switch self {
        case .jungle, .volcano, .deepOcean, .arcade, .neonCity, .arctic, .cherryBlossom: return true
        case .northwoods, .lakeSuperior, .midnightEmber, .aurora, .oledVoid: return true
        default: return false
        }
    }

    /// Free holiday and season themes. They show in the picker only during their window.
    var isSeasonal: Bool { ZallaThemeID.seasonal.contains(self) }

    /// Seasonal themes in calendar order.
    static var seasonal: [ZallaThemeID] { [.newYear, .winter, .valentines, .stPatricks, .easter, .spring, .memorialDay, .summer, .fourthOfJuly, .halloween, .harvest, .christmas] }

    /// Build 47 Pro accents.
    static var pro: [ZallaThemeID] { [.northwoods, .lakeSuperior, .midnightEmber, .aurora, .oledVoid] }

    var displayName: String {
        switch self {
        case .zallaRed: return "Zalla Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .violet: return "Violet"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .space: return "Space"
        case .jungle: return "Jungle"
        case .volcano: return "Volcano"
        case .deepOcean: return "Deep Ocean"
        case .arcade: return "Retro Arcade"
        case .neonCity: return "Neon City"
        case .arctic: return "Arctic"
        case .cherryBlossom: return "Cherry Blossom"
        case .northwoods: return "Northwoods"
        case .lakeSuperior: return "Lake Superior"
        case .midnightEmber: return "Midnight Ember"
        case .aurora: return "Aurora"
        case .oledVoid: return "OLED Void"
        case .newYear: return "New Year's"
        case .winter: return "Winter"
        case .valentines: return "Valentine's Day"
        case .stPatricks: return "Saint Patrick's Day"
        case .easter: return "Easter"
        case .spring: return "Spring"
        case .memorialDay: return "Memorial Day"
        case .summer: return "Summer"
        case .fourthOfJuly: return "Fourth of July"
        case .halloween: return "Halloween"
        case .harvest: return "Fall Harvest"
        case .christmas: return "Christmas"
        }
    }

    /// Featured accents shown first in Settings (refined, not a wall of chips).
    static var featured: [ZallaThemeID] { [.zallaRed, .ocean, .forest, .space, .jungle, .volcano, .deepOcean, .arcade, .neonCity, .arctic, .cherryBlossom, .northwoods, .lakeSuperior, .midnightEmber, .aurora, .oledVoid] }

    /// Secondary rainbow accents, presented more quietly.
    static var secondary: [ZallaThemeID] {
        [.orange, .yellow, .green, .blue, .indigo, .violet]
    }

    /// The shipped app icon drawn in this accent. Zalla Red is the primary icon.
    var suggestedAppIcon: AppIconPreference {
        switch self {
        case .zallaRed: return .default
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .indigo: return .indigo
        case .violet: return .violet
        case .ocean: return .ocean
        case .forest: return .forest
        case .space: return .space
        case .jungle: return .jungle
        case .volcano: return .volcano
        case .deepOcean: return .deepOcean
        case .arcade: return .arcade
        case .neonCity: return .neonCity
        case .arctic: return .arctic
        case .cherryBlossom: return .cherryBlossom
        case .northwoods: return .northwoods
        case .lakeSuperior: return .lakeSuperior
        case .midnightEmber: return .midnightEmber
        case .aurora: return .aurora
        case .oledVoid: return .oledVoid
        case .newYear: return .newYear
        case .winter: return .winter
        case .valentines: return .valentines
        case .stPatricks: return .stPatricks
        case .easter: return .easter
        case .spring: return .spring
        case .memorialDay: return .memorialDay
        case .summer: return .summer
        case .fourthOfJuly: return .fourthOfJuly
        case .halloween: return .halloween
        case .harvest: return .harvest
        case .christmas: return .christmas
        }
    }

    /// Main accent color as hex, used to match custom colors to the nearest shipped icon.
    var primaryHex: String {
        switch self {
        case .zallaRed: return "E33B4F"
        case .orange: return "F06A2F"
        case .yellow: return "E0A21A"
        case .green: return "2FA866"
        case .blue: return "2F6FED"
        case .indigo: return "4F5BD5"
        case .violet: return "8B3DDB"
        case .ocean: return "1F8A9E"
        case .forest: return "2F7A4A"
        case .space: return "6B7CFF"
        case .jungle: return "8DB63C"
        case .volcano: return "E8481C"
        case .deepOcean: return "14A3B8"
        case .arcade: return "FF4FB0"
        case .neonCity: return "E83CFF"
        case .arctic: return "5AB8E8"
        case .cherryBlossom: return "F0709C"
        case .northwoods: return "2E6B4F"
        case .lakeSuperior: return "4A6F8F"
        case .midnightEmber: return "C2361F"
        case .aurora: return "3FD9A0"
        case .oledVoid: return "9AA4B5"
        case .newYear: return "D4AF37"
        case .winter: return "6FA8DC"
        case .valentines: return "E0457B"
        case .stPatricks: return "1FA64A"
        case .easter: return "B79CF0"
        case .spring: return "6CC070"
        case .memorialDay: return "3A5BA8"
        case .summer: return "FFB020"
        case .fourthOfJuly: return "D7263D"
        case .halloween: return "F07A1A"
        case .harvest: return "C8642A"
        case .christmas: return "C8102E"
        }
    }
}

extension ZallaTheme {
    /// Maps a custom accent hex to the closest shipped icon: the nearest accent icon by color,
    /// Dark for very dark colors, and Tinted for grays.
    static func closestAppIcon(forCustomHex hex: String) -> AppIconPreference {
        let (r, g, b) = rgbComponents(from: hex)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if luminance < 0.12 {
            return .dark
        }
        if max(r, g, b) - min(r, g, b) < 0.12 {
            return .tinted
        }
        var best = ZallaThemeID.zallaRed
        var bestDistance = Double.greatestFiniteMagnitude
        for id in ZallaThemeID.allCases where !id.requiresUnlock && !id.isSeasonal {
            let distance = colorDistance((r, g, b), rgbComponents(from: id.primaryHex))
            if distance < bestDistance {
                bestDistance = distance
                best = id
            }
        }
        return best.suggestedAppIcon
    }

    /// Weighted RGB distance ("redmean"), closer to perceived difference than plain RGB.
    static func colorDistance(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let meanRed = (a.0 + b.0) / 2
        let dr = a.0 - b.0
        let dg = a.1 - b.1
        let db = a.2 - b.2
        return (2 + meanRed) * dr * dr + 4 * dg * dg + (3 - meanRed) * db * db
    }

    /// Resolves the recommended icon for the current accent settings.
    static func recommendedAppIcon(themeID: String, useCustom: Bool, customHex: String) -> AppIconPreference {
        if useCustom {
            return closestAppIcon(forCustomHex: customHex)
        }
        return (ZallaThemeID(rawValue: themeID) ?? .zallaRed).suggestedAppIcon
    }
}

struct ZallaTheme: Equatable {
    let id: ZallaThemeID
    let primary: Color
    let bright: Color
    let deep: Color
    let highlight: Color
    let gradientEnd: Color
    var usesGradientAccent: Bool = true

    var gradient: LinearGradient {
        if usesGradientAccent {
            return LinearGradient(colors: [primary, gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [primary, primary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func hex(_ value: String) -> Color {
        let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        } else {
            r = 0.89; g = 0.23; b = 0.31
        }
        return Color(red: r, green: g, blue: b)
    }

    static func theme(for id: ZallaThemeID) -> ZallaTheme {
        switch id {
        case .zallaRed:
            return ZallaTheme(id: id, primary: hex("E33B4F"), bright: hex("FF5266"), deep: hex("A91F36"), highlight: hex("FF6B63"), gradientEnd: hex("D83B72"))
        case .orange:
            return ZallaTheme(id: id, primary: hex("F06A2F"), bright: hex("FF8A4A"), deep: hex("B54716"), highlight: hex("FF9B6B"), gradientEnd: hex("F08A3C"))
        case .yellow:
            return ZallaTheme(id: id, primary: hex("E0A21A"), bright: hex("F5C84B"), deep: hex("A87410"), highlight: hex("FFD56A"), gradientEnd: hex("E8B84A"))
        case .green:
            return ZallaTheme(id: id, primary: hex("2FA866"), bright: hex("4BC98A"), deep: hex("1E7A4A"), highlight: hex("6ED9A0"), gradientEnd: hex("3BBF8A"))
        case .blue:
            return ZallaTheme(id: id, primary: hex("2F6FED"), bright: hex("5B8FFF"), deep: hex("1E4BB8"), highlight: hex("7AA7FF"), gradientEnd: hex("4B7CF0"))
        case .indigo:
            return ZallaTheme(id: id, primary: hex("4F5BD5"), bright: hex("6E78E8"), deep: hex("343CA8"), highlight: hex("8B93F0"), gradientEnd: hex("5A4FD0"))
        case .violet:
            return ZallaTheme(id: id, primary: hex("8B3DDB"), bright: hex("A85CF0"), deep: hex("5E2499"), highlight: hex("C07AFF"), gradientEnd: hex("9B4DE0"))
        case .ocean:
            return ZallaTheme(id: id, primary: hex("1F8A9E"), bright: hex("2EB7C9"), deep: hex("0F5C6B"), highlight: hex("5DD0DC"), gradientEnd: hex("2A6FBF"))
        case .forest:
            return ZallaTheme(id: id, primary: hex("2F7A4A"), bright: hex("4A9B64"), deep: hex("1B4D30"), highlight: hex("6BB87A"), gradientEnd: hex("3A6B3F"))
        case .space:
            return ZallaTheme(id: id, primary: hex("6B7CFF"), bright: hex("8B9BFF"), deep: hex("3A4499"), highlight: hex("B0A0FF"), gradientEnd: hex("9B6BFF"))
        case .jungle:
            return ZallaTheme(id: id, primary: hex("8DB63C"), bright: hex("A8D354"), deep: hex("4E6F1E"), highlight: hex("C5E27A"), gradientEnd: hex("3F9B4E"))
        case .volcano:
            return ZallaTheme(id: id, primary: hex("E8481C"), bright: hex("FF6A2E"), deep: hex("9E2410"), highlight: hex("FFA14A"), gradientEnd: hex("FF8A1E"))
        case .deepOcean:
            return ZallaTheme(id: id, primary: hex("14A3B8"), bright: hex("3CD0E0"), deep: hex("0B5F70"), highlight: hex("8FEAF0"), gradientEnd: hex("1E7FC4"))
        case .arcade:
            return ZallaTheme(id: id, primary: hex("FF4FB0"), bright: hex("FF7AC8"), deep: hex("A3216F"), highlight: hex("FFE35A"), gradientEnd: hex("4F7BFF"))
        case .neonCity:
            return ZallaTheme(id: id, primary: hex("E83CFF"), bright: hex("FF6BFF"), deep: hex("8A1FA8"), highlight: hex("5CF2FF"), gradientEnd: hex("2AD9FF"))
        case .arctic:
            return ZallaTheme(id: id, primary: hex("5AB8E8"), bright: hex("8AD2F5"), deep: hex("2A7BAF"), highlight: hex("CBEFFF"), gradientEnd: hex("7FA8F5"))
        case .cherryBlossom:
            return ZallaTheme(id: id, primary: hex("F0709C"), bright: hex("FF92B8"), deep: hex("B03F68"), highlight: hex("FFC2D6"), gradientEnd: hex("E86FB8"))
        case .northwoods:
            return ZallaTheme(id: id, primary: hex("2E6B4F"), bright: hex("4A8F6C"), deep: hex("173D2C"), highlight: hex("F2B84B"), gradientEnd: hex("D49A3A"))
        case .lakeSuperior:
            return ZallaTheme(id: id, primary: hex("4A6F8F"), bright: hex("6B8FAF"), deep: hex("2B4560"), highlight: hex("FF7A2F"), gradientEnd: hex("7F95A8"))
        case .midnightEmber:
            return ZallaTheme(id: id, primary: hex("C2361F"), bright: hex("E85A33"), deep: hex("6E160C"), highlight: hex("FFB067"), gradientEnd: hex("F07A24"))
        case .aurora:
            return ZallaTheme(id: id, primary: hex("3FD9A0"), bright: hex("6FF0BE"), deep: hex("1E7F66"), highlight: hex("B48CFF"), gradientEnd: hex("8A5CF0"))
        case .oledVoid:
            return ZallaTheme(id: id, primary: hex("9AA4B5"), bright: hex("C3CAD6"), deep: hex("5E6675"), highlight: hex("E6EAF0"), gradientEnd: hex("9AA4B5"), usesGradientAccent: false)
        case .newYear:
            return ZallaTheme(id: id, primary: hex("D4AF37"), bright: hex("F0CF60"), deep: hex("8F7420"), highlight: hex("FFF1B0"), gradientEnd: hex("C0C6D0"))
        case .winter:
            return ZallaTheme(id: id, primary: hex("6FA8DC"), bright: hex("9CC8EE"), deep: hex("3C6E9E"), highlight: hex("E6F3FF"), gradientEnd: hex("8FA0E8"))
        case .valentines:
            return ZallaTheme(id: id, primary: hex("E0457B"), bright: hex("FF6F9C"), deep: hex("A0234F"), highlight: hex("FFC1D3"), gradientEnd: hex("C2185B"))
        case .stPatricks:
            return ZallaTheme(id: id, primary: hex("1FA64A"), bright: hex("3FCB6B"), deep: hex("0F6B2E"), highlight: hex("F2D16B"), gradientEnd: hex("2E8B57"))
        case .easter:
            return ZallaTheme(id: id, primary: hex("B79CF0"), bright: hex("CDB8FF"), deep: hex("7A60B8"), highlight: hex("FFF0A8"), gradientEnd: hex("8FD6C8"))
        case .spring:
            return ZallaTheme(id: id, primary: hex("6CC070"), bright: hex("8FDB8F"), deep: hex("3E8A45"), highlight: hex("FFD1E0"), gradientEnd: hex("E88AB0"))
        case .memorialDay:
            return ZallaTheme(id: id, primary: hex("3A5BA8"), bright: hex("5A7BC8"), deep: hex("1C2F5C"), highlight: hex("D23C3C"), gradientEnd: hex("B33A3A"))
        case .summer:
            return ZallaTheme(id: id, primary: hex("FFB020"), bright: hex("FFC94D"), deep: hex("C77A00"), highlight: hex("FFE38A"), gradientEnd: hex("FF6A4D"))
        case .fourthOfJuly:
            return ZallaTheme(id: id, primary: hex("D7263D"), bright: hex("F04A5E"), deep: hex("8F1626"), highlight: hex("FFFFFF"), gradientEnd: hex("2F5DCC"))
        case .halloween:
            return ZallaTheme(id: id, primary: hex("F07A1A"), bright: hex("FF9A3D"), deep: hex("A8480A"), highlight: hex("B26BFF"), gradientEnd: hex("8E3FD6"))
        case .harvest:
            return ZallaTheme(id: id, primary: hex("C8642A"), bright: hex("E0853F"), deep: hex("8A3D17"), highlight: hex("F2C14E"), gradientEnd: hex("A6451F"))
        case .christmas:
            return ZallaTheme(id: id, primary: hex("C8102E"), bright: hex("E8394F"), deep: hex("7F0A1C"), highlight: hex("F4D58D"), gradientEnd: hex("1E7B45"))
        }
    }

    static func theme(forRaw raw: String) -> ZallaTheme {
        let id = ZallaThemeID(rawValue: raw) ?? .zallaRed
        // Pack accents need Zalla Unlock. Without it, the default accent is used.
        if id.requiresUnlock, !ZallaUnlockCache.load() { return theme(for: .zallaRed) }
        return theme(for: id)
    }

    /// Resolves preset or custom accent for chrome tinting.
    static func resolved(themeID: String, useCustom: Bool, customHex: String, gradient: Bool = true) -> ZallaTheme {
        if useCustom {
            return custom(hexString: customHex, gradient: gradient)
        }
        return theme(forRaw: themeID)
    }

    static func custom(hexString: String, gradient: Bool) -> ZallaTheme {
        let primary = hex(normalizeHex(hexString) ?? "E33B4F")
        let bright = primary.opacity(0.92)
        let deep = primary.opacity(0.75)
        let end: Color
        if gradient {
            end = shifted(hexString: normalizeHex(hexString) ?? "E33B4F", towardHue: 0.08)
        } else {
            end = primary
        }
        return ZallaTheme(
            id: .zallaRed,
            primary: primary,
            bright: bright,
            deep: deep,
            highlight: bright,
            gradientEnd: end,
            usesGradientAccent: gradient
        )
    }

    static func normalizeHex(_ value: String) -> String? {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6,
              cleaned.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }) else {
            return nil
        }
        return cleaned.uppercased()
    }

    static func rgbComponents(from hexString: String) -> (Double, Double, Double) {
        let cleaned = normalizeHex(hexString) ?? "E33B4F"
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        return (r, g, b)
    }

    static func hexString(r: Double, g: Double, b: Double) -> String {
        let ri = Int(max(0, min(1, r)) * 255)
        let gi = Int(max(0, min(1, g)) * 255)
        let bi = Int(max(0, min(1, b)) * 255)
        return String(format: "%02X%02X%02X", ri, gi, bi)
    }

    private static func shifted(hexString: String, towardHue: Double) -> Color {
        let (r, g, b) = rgbComponents(from: hexString)
        // Mild shift toward a neighboring hue for gradient end without UIKit dependency in pure math.
        let nr = min(1, max(0, r * (1 - towardHue) + towardHue * 0.85))
        let ng = min(1, max(0, g * (1 - towardHue * 0.4)))
        let nb = min(1, max(0, b * (1 - towardHue) + towardHue * 0.55))
        return Color(red: nr, green: ng, blue: nb)
    }
}

enum AppIconPreference: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case dark = "Dark"
    case tinted = "Tinted"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case indigo = "Indigo"
    case violet = "Violet"
    case ocean = "Ocean"
    case forest = "Forest"
    case space = "Space"
    case jungle = "Jungle"
    case volcano = "Volcano"
    case deepOcean = "DeepOcean"
    case arcade = "RetroArcade"
    case neonCity = "NeonCity"
    case arctic = "Arctic"
    case cherryBlossom = "CherryBlossom"
    case northwoods = "Northwoods"
    case lakeSuperior = "LakeSuperior"
    case midnightEmber = "MidnightEmber"
    case aurora = "Aurora"
    case oledVoid = "OLEDVoid"
    case newYear = "NewYear"
    case winter = "Winter"
    case valentines = "Valentines"
    case stPatricks = "StPatricks"
    case easter = "Easter"
    case spring = "Spring"
    case memorialDay = "MemorialDay"
    case summer = "Summer"
    case fourthOfJuly = "FourthOfJuly"
    case halloween = "Halloween"
    case harvest = "Harvest"
    case christmas = "Christmas"

    var id: String { rawValue }

    /// Name shown in Settings. Raw values stay free of spaces because they build asset names.
    var displayName: String {
        switch self {
        case .deepOcean: return "Deep Ocean"
        case .arcade: return "Retro Arcade"
        case .neonCity: return "Neon City"
        case .cherryBlossom: return "Cherry Blossom"
        case .lakeSuperior: return "Lake Superior"
        case .midnightEmber: return "Midnight Ember"
        case .oledVoid: return "OLED Void"
        case .newYear: return "New Year's"
        case .valentines: return "Valentine's Day"
        case .stPatricks: return "Saint Patrick's Day"
        case .memorialDay: return "Memorial Day"
        case .fourthOfJuly: return "Fourth of July"
        case .harvest: return "Fall Harvest"
        default: return rawValue
        }
    }

    /// Jungle and the newer theme icons are part of their theme packs, so they need Zalla Unlock to pick.
    var requiresUnlock: Bool {
        switch self {
        case .jungle, .volcano, .deepOcean, .arcade, .neonCity, .arctic, .cherryBlossom: return true
        case .northwoods, .lakeSuperior, .midnightEmber, .aurora, .oledVoid: return true
        default: return false
        }
    }

    /// Alternate icon name passed to UIApplication.setAlternateIconName. nil restores primary.
    /// Each name matches an .appiconset in Assets.xcassets and an entry in project.yml.
    var alternateIconName: String? {
        switch self {
        case .default: return nil
        default: return "AppIcon\(rawValue)"
        }
    }

    /// Small copy of the icon for Settings. App icon sets cannot be loaded with UIImage(named:).
    var previewImageName: String {
        "IconPreview\(rawValue)"
    }

    static func apply(_ preference: AppIconPreference, completion: ((String?) -> Void)? = nil) {
        guard UIApplication.shared.supportsAlternateIcons else {
            completion?("Alternate icons aren't available right now.")
            return
        }
        let name = preference.alternateIconName
        if UIApplication.shared.alternateIconName == name {
            completion?(nil)
            return
        }
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                if let error {
                    completion?(error.localizedDescription)
                } else {
                    completion?(nil)
                }
            }
        }
    }
}

enum HomeWelcomeMode: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case name = "Named welcome"
    case quotes = "Rotating quotes"

    var id: String { rawValue }

    static let storageKey = "homeWelcomeMode"
    static let userNameKey = "homeUserName"
}
