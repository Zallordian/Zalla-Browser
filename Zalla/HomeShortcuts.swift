import Foundation
import SwiftUI

struct HomeShortcut: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var urlString: String
    var symbolName: String

    var url: URL? { URL(string: urlString) }

    init(id: UUID = UUID(), title: String, urlString: String, symbolName: String) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.symbolName = symbolName
    }
}

enum HomeShortcuts {
    static let storageKey = "homeShortcuts"
    static let showRecentHistoryKey = "homeShowRecentHistory"
    static let washIntensityKey = "homeWashIntensity"
    static let showLogoKey = "homeShowLogo"

    /// Curated SF Symbols for shortcut icons.
    static let curatedSymbols: [String] = [
        "globe",
        "magnifyingglass",
        "book",
        "newspaper",
        "envelope",
        "lock.shield",
        "music.note",
        "play.rectangle",
        "cart",
        "map",
        "cloud",
        "bubble.left.and.bubble.right",
        "person.crop.circle",
        "star",
        "heart",
        "house",
        "safari",
        "link",
        "doc.text",
        "folder",
        "bolt",
        "leaf",
        "camera",
        "gamecontroller"
    ]

    static let defaults: [HomeShortcut] = [
        HomeShortcut(title: "DuckDuckGo", urlString: "https://duckduckgo.com", symbolName: "magnifyingglass"),
        HomeShortcut(title: "Wikipedia", urlString: "https://wikipedia.org", symbolName: "book"),
        HomeShortcut(title: "Apple", urlString: "https://www.apple.com", symbolName: "apple.logo"),
        HomeShortcut(title: "Proton Mail", urlString: "https://mail.proton.me", symbolName: "envelope"),
        HomeShortcut(title: "GitHub", urlString: "https://github.com", symbolName: "chevron.left.forwardslash.chevron.right"),
        HomeShortcut(title: "Maps", urlString: "https://maps.apple.com", symbolName: "map")
    ]

    static func load(from defaults: UserDefaults = .standard) -> [HomeShortcut] {
        guard let data = defaults.data(forKey: storageKey) else {
            return Self.defaults
        }
        do {
            let decoded = try JSONDecoder().decode([HomeShortcut].self, from: data)
            return decoded.isEmpty ? Self.defaults : decoded
        } catch {
            return Self.defaults
        }
    }

    static func save(_ shortcuts: [HomeShortcut], to defaults: UserDefaults = .standard) {
        do {
            let data = try JSONEncoder().encode(shortcuts)
            defaults.set(data, forKey: storageKey)
        } catch {
            // Persistence failures surface via BrowserStore when wired; ignore here.
        }
    }

    static func resetToDefaults(in defaults: UserDefaults = .standard) {
        save(Self.defaults, to: defaults)
        defaults.set(true, forKey: showRecentHistoryKey)
        defaults.set(0.35, forKey: washIntensityKey)
        defaults.set(true, forKey: showLogoKey)
    }

    /// Pure helper for tests: seed defaults when the stored list is empty or missing.
    static func seededIfEmpty(_ existing: [HomeShortcut]?) -> [HomeShortcut] {
        guard let existing, !existing.isEmpty else { return Self.defaults }
        return existing
    }
}
