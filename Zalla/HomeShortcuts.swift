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
    static let hideAddHintKey = "homeHideAddShortcutHint"

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

    private static let symbolLabels: [String: String] = [
        "magnifyingglass": "Search",
        "newspaper": "News",
        "lock.shield": "Lock and shield",
        "music.note": "Music",
        "play.rectangle": "Video",
        "cart": "Shopping cart",
        "bubble.left.and.bubble.right": "Chat",
        "person.crop.circle": "Person",
        "safari": "Compass",
        "doc.text": "Document",
        "bolt": "Lightning bolt",
        "gamecontroller": "Game controller",
        "apple.logo": "Apple",
        "chevron.left.forwardslash.chevron.right": "Code"
    ]

    /// What VoiceOver reads for an icon choice. Falls back to the symbol name with the dots turned into spaces.
    static func symbolLabel(_ name: String) -> String {
        if let friendly = symbolLabels[name] { return friendly }
        return name.replacingOccurrences(of: ".", with: " ")
    }

    /// Fresh installs and resets start with no shortcuts. Existing users keep the list they already have.
    static let defaults: [HomeShortcut] = []

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
        defaults.removeObject(forKey: hideAddHintKey)
        defaults.set(true, forKey: showRecentHistoryKey)
        defaults.set(0.35, forKey: washIntensityKey)
        defaults.set(true, forKey: showLogoKey)
        defaults.removeObject(forKey: LogoStyle.storageKey)
        defaults.set(true, forKey: showSliderKey)
        defaults.set(HomeWelcomeMode.quotes.rawValue, forKey: HomeWelcomeMode.storageKey)
        defaults.removeObject(forKey: HomeWelcomeMode.userNameKey)
    }

    /// Pure helper for tests: the default (empty) list when nothing is stored, else the stored list.
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

/// Adding and checking shortcuts. Pure helpers so the rules can be tested without a screen.
extension HomeShortcuts {
    /// The most shortcuts the new tab page keeps. Plenty, and it stops runaway lists.
    static let maxShortcuts = 48

    /// A web address from what someone typed: https is added when missing, and it needs a real host.
    /// Returns nil when it cannot be opened as a website.
    static func normalizedURLString(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace }) else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = HTTPSOnly.normalizedHost(url.host),
              host.contains(".") || HTTPSOnly.isLocalOrPrivate(host) else { return nil }
        return url.absoluteString
    }

    /// A shortcut from typed title and address, or nil when either is unusable.
    static func makeShortcut(title: String, urlString: String, symbolName: String = "globe") -> HomeShortcut? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, let normalized = normalizedURLString(urlString) else { return nil }
        return HomeShortcut(title: cleanTitle, urlString: normalized, symbolName: symbolName)
    }

    /// Key used to spot the same site added twice: no scheme, no www, no trailing slash, any case.
    static func duplicateKey(_ urlString: String) -> String {
        var key = urlString.lowercased()
        for prefix in ["https://", "http://"] where key.hasPrefix(prefix) {
            key.removeFirst(prefix.count)
        }
        if key.hasPrefix("www.") { key.removeFirst(4) }
        while key.hasSuffix("/") { key.removeLast() }
        return key
    }

    static func contains(_ list: [HomeShortcut], urlString: String) -> Bool {
        let key = duplicateKey(urlString)
        return list.contains { duplicateKey($0.urlString) == key }
    }

    /// Adds a shortcut to the saved list. False when it is already there or the list is full.
    @discardableResult
    static func add(_ shortcut: HomeShortcut, in defaults: UserDefaults = .standard) -> Bool {
        var list = load(from: defaults)
        guard list.count < maxShortcuts, !contains(list, urlString: shortcut.urlString) else { return false }
        list.append(shortcut)
        save(list, to: defaults)
        return true
    }
}
