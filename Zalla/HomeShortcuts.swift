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
    static let showSliderKey = "homeShowSlider"

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
            // Preserve an intentionally empty list so the new-tab empty state can appear.
            return try JSONDecoder().decode([HomeShortcut].self, from: data)
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
        defaults.set(true, forKey: showSliderKey)
        defaults.set(HomeWelcomeMode.quotes.rawValue, forKey: HomeWelcomeMode.storageKey)
        defaults.removeObject(forKey: HomeWelcomeMode.userNameKey)
    }

    /// Pure helper for tests: seed defaults when the stored list is empty or missing.
    static func seededIfEmpty(_ existing: [HomeShortcut]?) -> [HomeShortcut] {
        guard let existing, !existing.isEmpty else { return Self.defaults }
        return existing
    }
}

/// Pure helpers for the new tab home slider. Widgets only use data already on this device.
enum HomeWidgets {
    static let recentHistoryLimit = 3

    enum Page: String, Equatable {
        case welcome
        case tabs
        case recent
    }

    /// Pages shown in the home slider. Welcome is always first. Recent history is hidden
    /// in private tabs, when turned off, or when there is nothing to show.
    static func pages(
        sliderEnabled: Bool,
        showRecentHistory: Bool,
        isPrivate: Bool,
        hasHistory: Bool
    ) -> [Page] {
        guard sliderEnabled else { return [.welcome] }
        var pages: [Page] = [.welcome, .tabs]
        if showRecentHistory, !isPrivate, hasHistory {
            pages.append(.recent)
        }
        return pages
    }

    /// Most recent unique pages by URL, newest first.
    static func recentPages(_ history: [SavedPage], limit: Int = recentHistoryLimit) -> [SavedPage] {
        var seen = Set<URL>()
        var result: [SavedPage] = []
        for page in history where !seen.contains(page.url) {
            seen.insert(page.url)
            result.append(page)
            if result.count >= limit { break }
        }
        return result
    }

    static func tabCountLabel(_ count: Int) -> String {
        count == 1 ? "1 tab open" : "\(count) tabs open"
    }

    static func privateTabLabel(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? "1 private" : "\(count) private"
    }

    /// Title for a recent page row, falling back to its host.
    static func displayTitle(for page: SavedPage) -> String {
        let trimmed = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return AddressDisplay.friendlyHost(from: page.url) ?? page.url.absoluteString
    }
}
