import SwiftUI

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
}

struct ZallaTheme: Equatable {
    let id: ZallaThemeID
    let primary: Color
    let bright: Color
    let deep: Color
    let highlight: Color
    let gradientEnd: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [primary, gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
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
}
