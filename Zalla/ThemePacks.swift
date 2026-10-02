import Foundation

/// A theme pack bundles an accent, a matching app icon, a new tab background, and an optional full-screen transition.
/// Packs are part of Zalla Unlock. The Space accent and icon stay free on their own, as they always were. Jungle, Volcano, Deep Ocean, and Retro Arcade are locked as a whole.
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

/// What tapping a swatch in Settings, Appearance does. A theme with a pack applies the whole look (accent, app icon,
/// new tab background, and refresh transition); a plain accent only sets the color and offers the matching icon.
enum QuickTheme {
    /// Settings, Appearance: swatches apply the whole theme. On by default; off makes every swatch set the accent only.
    static let storageKey = "quickThemeFullLook"
    static let defaultEnabled = true

    enum Action: Equatable {
        /// A locked theme without Zalla Unlock: show the Unlock sheet and change nothing.
        case needsUnlock
        /// Set the accent and offer the matching icon, as swatches always did.
        case accentOnly
        /// Set accent, icon, new tab background, and play the transition.
        case fullPack(ThemePack)
    }

    static func action(for id: ZallaThemeID, unlocked: Bool, fullLook: Bool) -> Action {
        if id.requiresUnlock && !unlocked { return .needsUnlock }
        // The pack's backgrounds and transition are part of Zalla Unlock, so without it only the accent is set.
        if fullLook, unlocked, let pack = ThemePacks.pack(for: id.rawValue) { return .fullPack(pack) }
        return .accentOnly
    }
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
        ),
        ThemePack(
            id: "volcano",
            name: "Volcano",
            tagline: "Black rock, ember red, and a wall of lava with flying sparks on refresh.",
            themeID: .volcano,
            icon: .volcano,
            backgroundPresetID: "lava",
            transition: .volcano,
            symbolName: "flame"
        ),
        ThemePack(
            id: "deepocean",
            name: "Deep Ocean",
            tagline: "Deep teal, aqua, bubbles, and a wave that rolls across and pulls back on refresh.",
            themeID: .deepOcean,
            icon: .deepOcean,
            backgroundPresetID: "lagoon",
            transition: .ocean,
            symbolName: "water.waves"
        ),
        ThemePack(
            id: "arcade",
            name: "Retro Arcade",
            tagline: "Pixel stars in pink, blue, and yellow, and a CRT pixel dissolve on refresh.",
            themeID: .arcade,
            icon: .arcade,
            backgroundPresetID: "cabinet",
            transition: .arcade,
            symbolName: "gamecontroller"
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
