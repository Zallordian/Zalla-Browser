import Foundation

/// A generated background for the new tab page. Colors are hex strings, drawn in code, so no image assets ship.
struct NewTabPreset: Identifiable, Equatable {
    enum Style: Equatable {
        case linear
        case radial
    }

    /// Optional drawn details on top of the gradient. Static, so they cost no battery.
    enum Decor: Equatable {
        case none
        case stars
        case leaves
        case embers
        case bubbles
        case pixels
    }

    let id: String
    let name: String
    let colors: [String]
    let style: Style
    /// Dark backgrounds show the new tab text in its light style.
    let isDark: Bool
    /// Pack id for Zalla Unlock backgrounds, nil for the free ones.
    let pack: String?
    var decor: Decor = .none

    var requiresUnlock: Bool { pack != nil }
}

struct NewTabPack: Identifiable, Equatable {
    let id: String
    let name: String
}

enum NewTabCatalog {
    static let free: [NewTabPreset] = [
        NewTabPreset(id: "crimson", name: "Crimson", colors: ["E33B4F", "8F1B31"], style: .linear, isDark: true, pack: nil),
        NewTabPreset(id: "rose", name: "Rose", colors: ["FFC2CD", "F27C90"], style: .linear, isDark: false, pack: nil),
        NewTabPreset(id: "graphite", name: "Graphite", colors: ["34343B", "121215"], style: .linear, isDark: true, pack: nil),
        NewTabPreset(id: "snow", name: "Snow", colors: ["FFFFFF", "E9E9F0"], style: .linear, isDark: false, pack: nil)
    ]

    static let packs: [NewTabPack] = [
        NewTabPack(id: "warm", name: "Warm Pack"),
        NewTabPack(id: "cool", name: "Cool Pack"),
        NewTabPack(id: "nature", name: "Nature Pack"),
        NewTabPack(id: "space", name: "Space Pack"),
        NewTabPack(id: "jungle", name: "Jungle Pack"),
        NewTabPack(id: "volcano", name: "Volcano Pack"),
        NewTabPack(id: "deepocean", name: "Deep Ocean Pack"),
        NewTabPack(id: "arcade", name: "Arcade Pack")
    ]

    static let packed: [NewTabPreset] = [
        NewTabPreset(id: "sunset", name: "Sunset", colors: ["FF9A5A", "E33B4F", "6E1F5C"], style: .linear, isDark: true, pack: "warm"),
        NewTabPreset(id: "ember", name: "Ember", colors: ["F06A2F", "A91F36", "35101B"], style: .radial, isDark: true, pack: "warm"),
        NewTabPreset(id: "peach", name: "Peach", colors: ["FFE1D0", "FFB3A7"], style: .linear, isDark: false, pack: "warm"),
        NewTabPreset(id: "copper", name: "Copper", colors: ["C98555", "5F3421"], style: .linear, isDark: true, pack: "warm"),
        NewTabPreset(id: "ocean", name: "Ocean", colors: ["2EB7C9", "1F5FBF", "0B2A55"], style: .linear, isDark: true, pack: "cool"),
        NewTabPreset(id: "glacier", name: "Glacier", colors: ["EAF7FF", "B5DBF2"], style: .linear, isDark: false, pack: "cool"),
        NewTabPreset(id: "midnight", name: "Midnight", colors: ["262B66", "0A0B1E"], style: .radial, isDark: true, pack: "cool"),
        NewTabPreset(id: "aurora", name: "Aurora", colors: ["3DDC97", "2F6FED", "6B3DDB"], style: .linear, isDark: true, pack: "cool"),
        NewTabPreset(id: "forest", name: "Forest", colors: ["3B8F5B", "0F2D1B"], style: .linear, isDark: true, pack: "nature"),
        NewTabPreset(id: "meadow", name: "Meadow", colors: ["E2F6D0", "9AD08F"], style: .linear, isDark: false, pack: "nature"),
        NewTabPreset(id: "dune", name: "Dune", colors: ["F6E8C8", "D8B77F"], style: .linear, isDark: false, pack: "nature"),
        NewTabPreset(id: "stone", name: "Stone", colors: ["8E939C", "464A52"], style: .linear, isDark: true, pack: "nature"),
        NewTabPreset(id: "nebula", name: "Nebula", colors: ["4B2AA8", "1B1145", "07071A"], style: .radial, isDark: true, pack: "space", decor: .stars),
        NewTabPreset(id: "deepspace", name: "Deep Space", colors: ["10112B", "000000"], style: .linear, isDark: true, pack: "space", decor: .stars),
        NewTabPreset(id: "moonrise", name: "Moonrise", colors: ["8B9BFF", "2A2F73", "0D0E2A"], style: .linear, isDark: true, pack: "space", decor: .stars),
        NewTabPreset(id: "canopy", name: "Canopy", colors: ["3F9B4E", "17472B", "071A0F"], style: .linear, isDark: true, pack: "jungle", decor: .leaves),
        NewTabPreset(id: "understory", name: "Understory", colors: ["8DB63C", "2F5F2A"], style: .linear, isDark: true, pack: "jungle", decor: .leaves),
        NewTabPreset(id: "monsoon", name: "Monsoon", colors: ["1F4D3A", "07160F"], style: .radial, isDark: true, pack: "jungle", decor: .leaves),
        NewTabPreset(id: "mist", name: "Mist", colors: ["E4F0D0", "A5C883"], style: .linear, isDark: false, pack: "jungle", decor: .leaves),
        NewTabPreset(id: "lava", name: "Lava", colors: ["E8481C", "7A1608", "1A0505"], style: .radial, isDark: true, pack: "volcano", decor: .embers),
        NewTabPreset(id: "obsidian", name: "Obsidian", colors: ["3A2626", "0B0707"], style: .linear, isDark: true, pack: "volcano", decor: .embers),
        NewTabPreset(id: "caldera", name: "Caldera", colors: ["FF8A1E", "B2230F", "2B0707"], style: .linear, isDark: true, pack: "volcano", decor: .embers),
        NewTabPreset(id: "lagoon", name: "Lagoon", colors: ["2EC4C9", "0F6F86", "042A3A"], style: .linear, isDark: true, pack: "deepocean", decor: .bubbles),
        NewTabPreset(id: "abyss", name: "Abyss", colors: ["0B4A5E", "010F1A"], style: .radial, isDark: true, pack: "deepocean", decor: .bubbles),
        NewTabPreset(id: "reef", name: "Reef", colors: ["1FB5BD", "0A5C73"], style: .linear, isDark: true, pack: "deepocean", decor: .bubbles),
        NewTabPreset(id: "cabinet", name: "Cabinet", colors: ["FF4FB0", "5B1F8F", "0D0B2E"], style: .linear, isDark: true, pack: "arcade", decor: .pixels),
        NewTabPreset(id: "synthgrid", name: "Synthgrid", colors: ["4F7BFF", "241A66", "0A0820"], style: .linear, isDark: true, pack: "arcade", decor: .pixels),
        NewTabPreset(id: "pixelsky", name: "Pixel Sky", colors: ["1B1450", "07051A"], style: .radial, isDark: true, pack: "arcade", decor: .pixels)
    ]

    static var all: [NewTabPreset] { free + packed }

    static func preset(id: String) -> NewTabPreset? {
        all.first { $0.id == id }
    }

    static func presets(inPack pack: String) -> [NewTabPreset] {
        packed.filter { $0.pack == pack }
    }
}

/// The user's choice for the new tab background, stored as one short string.
enum NewTabBackground: Equatable {
    /// The theme wash Zalla has always used.
    case standard
    case preset(String)
    /// A photo the user picked, stored on this device.
    case photo

    static let storageKey = "newTabBackground"

    var storageValue: String {
        switch self {
        case .standard: return "standard"
        case .preset(let id): return "preset:" + id
        case .photo: return "photo"
        }
    }

    init(storageValue: String?) {
        guard let value = storageValue else {
            self = .standard
            return
        }
        if value == "photo" {
            self = .photo
        } else if value.hasPrefix("preset:") {
            let id = String(value.dropFirst("preset:".count))
            self = NewTabCatalog.preset(id: id) == nil ? .standard : .preset(id)
        } else {
            self = .standard
        }
    }

    /// What is actually drawn. Zalla Unlock backgrounds fall back to the standard look if the unlock is gone.
    func effective(unlocked: Bool, hasPhoto: Bool) -> NewTabBackground {
        switch self {
        case .standard:
            return .standard
        case .photo:
            return hasPhoto ? .photo : .standard
        case .preset(let id):
            guard let preset = NewTabCatalog.preset(id: id) else { return .standard }
            return preset.requiresUnlock && !unlocked ? .standard : self
        }
    }

    /// Whether the text on top of this background should use the light (dark mode) style. Nil keeps the system style.
    var prefersDarkContent: Bool? {
        switch self {
        case .standard: return nil
        case .photo: return true
        case .preset(let id): return NewTabCatalog.preset(id: id)?.isDark
        }
    }
}
