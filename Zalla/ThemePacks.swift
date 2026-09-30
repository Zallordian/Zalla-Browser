import Foundation

/// A theme pack bundles an accent, a matching app icon, a new tab background, and an optional refresh animation.
/// Packs are part of Zalla Unlock. The Space accent and icon stay free on their own, as they always were.
struct ThemePack: Identifiable, Equatable {
    enum Refresh: String, Equatable {
        case rocket
        case tree
    }

    let id: String
    let name: String
    let tagline: String
    let themeID: ZallaThemeID
    let icon: AppIconPreference
    let backgroundPresetID: String
    let refresh: Refresh
    let symbolName: String

    /// What the refresh animation draws.
    var refreshGlyph: String {
        switch refresh {
        case .rocket: return "\u{1F680}"
        case .tree: return "\u{1F334}"
        }
    }
}

enum ThemePacks {
    /// Turns the refresh animation off. It is on by default and always yields to Reduce Motion.
    static let refreshAnimationKey = "themeRefreshAnimation"

    static let all: [ThemePack] = [
        ThemePack(
            id: "space",
            name: "Space",
            tagline: "Stars, a purple-blue glow, and a rocket for every refresh.",
            themeID: .space,
            icon: .space,
            backgroundPresetID: "nebula",
            refresh: .rocket,
            symbolName: "sparkles"
        ),
        ThemePack(
            id: "jungle",
            name: "Jungle",
            tagline: "Leaves, deep greens, and a tree that brushes past on refresh.",
            themeID: .jungle,
            icon: .jungle,
            backgroundPresetID: "canopy",
            refresh: .tree,
            symbolName: "leaf"
        )
    ]

    static func pack(for themeID: String) -> ThemePack? {
        all.first { $0.themeID.rawValue == themeID }
    }

    static func refreshAnimationEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: refreshAnimationKey) as? Bool ?? true
    }

    /// The pack whose refresh animation should play right now, or nil when nothing should animate.
    static func activeRefresh(themeID: String, useCustomAccent: Bool, unlocked: Bool,
                              animationOn: Bool, reduceMotion: Bool) -> ThemePack? {
        guard unlocked, animationOn, !reduceMotion, !useCustomAccent else { return nil }
        return pack(for: themeID)
    }
}
