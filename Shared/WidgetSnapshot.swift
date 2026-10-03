import Foundation

// Shared by the app and the widget extension (both targets compile this folder). Foundation only.
// The app writes one small JSON snapshot into the shared App Group, and the widgets only ever read it.
// The snapshot holds the accent color, the favorites the person already has (home shortcuts and bookmarks), and
// the Privacy Report counts. It never holds history, tab URLs, or anything from a private tab, and no widget
// makes a network call.

struct WidgetLink: Codable, Equatable, Identifiable {
    var title: String
    var urlString: String
    var symbolName: String
    var id: String { urlString }
}

struct WidgetPrivacyCounts: Codable, Equatable {
    var linkCleaned = 0
    var httpsUpgrade = 0
    var cookieBannerDismissed = 0

    var total: Int { linkCleaned + httpsUpgrade + cookieBannerDismissed }
}

struct WidgetSnapshot: Codable, Equatable {
    var accentHex = WidgetShared.defaultAccentHex
    var shortcuts: [WidgetLink] = []
    var bookmarks: [WidgetLink] = []
    var privacy = WidgetPrivacyCounts()
    /// When the app last wrote this. Zero means the app has not written anything yet.
    var updatedAt = Date(timeIntervalSince1970: 0)

    var hasData: Bool { updatedAt.timeIntervalSince1970 > 0 }

    /// Same content, ignoring when it was written. Lets the app skip a rewrite (and a widget reload) that changes nothing.
    func sameContent(as other: WidgetSnapshot) -> Bool {
        var copy = other
        copy.updatedAt = updatedAt
        return copy == self
    }
}

enum WidgetShared {
    static let appGroup = "group.com.zalla.browser"
    static let storageKey = "widgetSnapshot"
    /// Settings switch (app side): turning it off clears the snapshot, and the widgets show their empty states.
    static let shareKey = "widgetsShareData"
    static let defaultShare = true
    static let maxLinks = 8
    static let maxTitleLength = 40
    static let defaultAccentHex = "E33B4F"

    static func sharedDefaults() -> UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load(from defaults: UserDefaults?) -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot, to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: storageKey)
    }

    static func clear(in defaults: UserDefaults?) {
        defaults?.removeObject(forKey: storageKey)
    }

    // MARK: - Links

    /// Keeps only web addresses (http or https with a host), trims titles (the host stands in for an empty one),
    /// drops repeats, and caps the list. Nothing else from the app ever gets into a widget.
    static func links(from items: [(title: String, urlString: String, symbolName: String)], limit: Int = maxLinks) -> [WidgetLink] {
        var seen = Set<String>()
        var result: [WidgetLink] = []
        for item in items {
            let raw = item.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https", let host = url.host, !host.isEmpty,
                  seen.insert(raw).inserted else { continue }
            let trimmed = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = String((trimmed.isEmpty ? host : trimmed).prefix(maxTitleLength))
            let symbol = item.symbolName.isEmpty ? "globe" : item.symbolName
            result.append(WidgetLink(title: title, urlString: raw, symbolName: symbol))
            if result.count == limit { break }
        }
        return result
    }

    /// `zalla://open?url=<address>`, which the app opens in a new tab. Nil for anything that is not a web address.
    static func openLink(for urlString: String) -> URL? {
        guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", !(url.host ?? "").isEmpty else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+#")
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "zalla://open?url=" + encoded)
    }

    static let searchLink = URL(string: "zalla://search")
    static let burnLink = URL(string: "zalla://burn")
    /// Opens Zalla and nothing else (the app ignores an open link with no address).
    static let appLink = URL(string: "zalla://open")

    // MARK: - Colors

    /// A six digit hex color, upper case, without the hash. Nil when it is not one.
    static func normalizedHex(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "# \n")).uppercased()
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isHexDigit }) else { return nil }
        return cleaned
    }

    static func rgb(fromHex value: String) -> (red: Double, green: Double, blue: Double) {
        let cleaned = normalizedHex(value) ?? defaultAccentHex
        var number: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&number)
        return (
            Double((number >> 16) & 0xFF) / 255,
            Double((number >> 8) & 0xFF) / 255,
            Double(number & 0xFF) / 255
        )
    }

    /// The accents a widget can be set to in its editor, besides following the app.
    static let palette: [(key: String, name: String, hex: String)] = [
        ("red", "Red", "E33B4F"),
        ("orange", "Orange", "F06A2F"),
        ("yellow", "Yellow", "E0A21A"),
        ("green", "Green", "2FA866"),
        ("blue", "Blue", "2F6FED"),
        ("indigo", "Indigo", "4F5BD5"),
        ("violet", "Violet", "8B3DDB"),
        ("pink", "Pink", "F0709C"),
        ("graphite", "Graphite", "4A4F5A")
    ]

    /// The hex a widget paints with. `followApp` (or an unknown key) uses the app's accent from the snapshot.
    static func resolvedAccentHex(choiceKey: String, snapshot: WidgetSnapshot) -> String {
        if let match = palette.first(where: { $0.key == choiceKey }) { return match.hex }
        return normalizedHex(snapshot.accentHex) ?? defaultAccentHex
    }

    /// How many favorites a widget shows: 4 in the medium widget, up to 8 in the large one, never more than set.
    static func favoriteCount(family: FavoritesFamily, setting: Int) -> Int {
        let ceiling: Int
        switch family {
        case .medium: ceiling = 4
        case .large: ceiling = 8
        }
        return max(1, min(setting, ceiling))
    }

    enum FavoritesFamily: Equatable {
        case medium
        case large
    }
}
