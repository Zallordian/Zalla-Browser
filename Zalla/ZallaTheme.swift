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

    var id: String { rawValue }

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
        }
    }

    /// Featured accents shown first in Settings (refined, not a wall of chips).
    static var featured: [ZallaThemeID] { [.zallaRed, .ocean, .forest, .space] }

    /// Secondary rainbow accents, presented more quietly.
    static var secondary: [ZallaThemeID] {
        [.orange, .yellow, .green, .blue, .indigo, .violet]
    }

    /// Best-fit alternate icon among shipped assets.
    var suggestedAppIcon: AppIconPreference {
        switch self {
        case .zallaRed, .orange, .yellow:
            return .default
        case .space, .indigo, .violet, .blue:
            return .dark
        case .ocean, .forest, .green:
            return .tinted
        }
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
        }
    }

    static func theme(forRaw raw: String) -> ZallaTheme {
        theme(for: ZallaThemeID(rawValue: raw) ?? .zallaRed)
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

    var id: String { rawValue }

    /// Alternate icon name passed to UIApplication.setAlternateIconName. nil restores primary.
    var alternateIconName: String? {
        switch self {
        case .default: return nil
        case .dark: return "AppIconDark"
        case .tinted: return "AppIconTinted"
        }
    }

    static func apply(_ preference: AppIconPreference, completion: ((String?) -> Void)? = nil) {
        guard UIApplication.shared.supportsAlternateIcons else {
            completion?("Alternate icons need a TestFlight or App Store build with CFBundleAlternateIcons configured.")
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

enum HomeQuotes {
    static let lines: [String] = [
        "Built around you.",
        "Browse at your own pace.",
        "Your tabs, your rhythm.",
        "Keep what matters close.",
        "A quieter place on the web.",
        "Start where you left off.",
        "Simple tools, ready when you are."
    ]

    static func quote(for date: Date = Date()) -> String {
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return lines[day % lines.count]
    }
}
