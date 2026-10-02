import Foundation

/// A theme pack bundles an accent, a matching app icon, a new tab background, and an optional full-screen transition.
/// Packs are part of Zalla Unlock. The Space accent and icon stay free on their own, as they always were.
struct ThemePack: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let themeID: ZallaThemeID
    let icon: AppIconPreference
    let backgroundPresetID: String
    let transition: ThemeTransitionKind
    let symbolName: String
}

enum ThemePacks {
    /// Turns theme transitions off. It is on by default; Reduce Motion turns them into a quick fade.
    /// The key keeps its Build 14 name, so anyone who switched the old animation off stays off.
    static let transitionsKey = "themeRefreshAnimation"

    static let all: [ThemePack] = [
        ThemePack(
            id: "space",
            name: "Space",
            tagline: "Stars, a purple-blue glow, and a rocket that crosses the screen on refresh.",
            themeID: .space,
            icon: .space,
            backgroundPresetID: "nebula",
            transition: .space,
            symbolName: "sparkles"
        ),
        ThemePack(
            id: "jungle",
            name: "Jungle",
            tagline: "Leaves, deep greens, and a leafy curtain that sweeps across on refresh.",
            themeID: .jungle,
            icon: .jungle,
            backgroundPresetID: "canopy",
            transition: .jungle,
            symbolName: "leaf"
        )
    ]

    static func pack(for themeID: String) -> ThemePack? {
        all.first { $0.themeID.rawValue == themeID }
    }

    /// What should play right now, or nil for nothing. Same gating as Build 14: a pack accent chosen by name,
    /// Zalla Unlock, and the switch on. Reduce Motion still plays, as a quick fade.
    static func activeTransition(themeID: String, useCustomAccent: Bool, unlocked: Bool, enabled: Bool,
                                 reduceMotion: Bool, speed: ThemeTransitionSpeed) -> ThemeTransitionPlan? {
        guard !useCustomAccent, let pack = pack(for: themeID) else { return nil }
        return ThemeTransitionPlan.make(kind: pack.transition, unlocked: unlocked, enabled: enabled,
                                        reduceMotion: reduceMotion, speed: speed)
    }
}
