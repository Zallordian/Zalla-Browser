import Foundation

/// The tabs across the top of Settings. Pure model, so the grouping is easy to test.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case privacy = "Privacy"
    case browsing = "Browsing"
    case tools = "Tools"
    case premium = "Premium"
    case about = "About"

    var id: String { rawValue }
    var title: String { rawValue }

    /// Remembers the tab you were on.
    static let storageKey = "settingsCategory"
    static let `default` = SettingsCategory.appearance

    var symbolName: String {
        switch self {
        case .appearance: return "paintpalette"
        case .privacy: return "lock.shield"
        case .browsing: return "safari"
        case .tools: return "wrench.and.screwdriver"
        case .premium: return "sparkles"
        case .about: return "info.circle"
        }
    }

    /// The sections that live under this tab, in the order they appear.
    var sections: [SettingsSection] {
        SettingsSection.allCases.filter { $0.category == self }
    }

    /// The saved tab, or Appearance when nothing valid is saved.
    static func stored(_ raw: String?) -> SettingsCategory {
        SettingsCategory(rawValue: raw ?? "") ?? .default
    }

    /// The tab a step to the left (-1) or right (+1) lands on, or nil at either end.
    func adjacent(_ offset: Int) -> SettingsCategory? {
        let all = SettingsCategory.allCases
        guard let index = all.firstIndex(of: self) else { return nil }
        let target = index + offset
        return all.indices.contains(target) ? all[target] : nil
    }
}

/// Every block of settings. The first ten are the sections of the old single-scroll Settings page, in their old order.
/// Each one lives under exactly one tab.
enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance
    case accent
    case appIcon
    case browsing
    case tools
    case privacy
    case ourPromise
    case supportZalla
    case privacyAndSupport
    case version
    /// New: Zalla Unlock status and a way to open it.
    case unlock
    /// Face ID for private tabs and Auto-clear, moved out of the old Privacy section.
    case premiumPrivacy

    var id: String { rawValue }

    var category: SettingsCategory {
        switch self {
        case .appearance, .accent, .appIcon: return .appearance
        case .privacy: return .privacy
        case .browsing: return .browsing
        case .tools: return .tools
        case .unlock, .premiumPrivacy: return .premium
        case .ourPromise, .supportZalla, .privacyAndSupport, .version: return .about
        }
    }

    /// The sections of the old single-scroll page.
    static let legacy: [SettingsSection] = [
        .appearance, .accent, .appIcon, .browsing, .tools, .privacy,
        .ourPromise, .supportZalla, .privacyAndSupport, .version
    ]
}
