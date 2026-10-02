import Foundation

/// What a page's apple-itunes-app meta tag told us.
struct AppBannerInfo: Equatable {
    /// The App Store id from `app-id`. Only digits. Used for nothing but the check that the tag is well formed:
    /// Zalla never contacts Apple or opens the App Store from it.
    var appID: String
    /// `app-argument`, when it is a web address on the same site as the page.
    var argument: URL?
    /// The name to show, taken from the page title or its host.
    var appName: String
    /// The page host the tag came from, without www or m.
    var hostKey: String
}

/// The Smart App Banner, Zalla style: read the meta tag the page already carries, show a slim banner, and try to open
/// the app through a universal link. Pure parsing here so it is easy to test.
enum AppBanner {
    /// Settings, Browsing, "App banners". On by default.
    static let storageKey = "appBanners"
    static let defaultEnabled = true

    static func isEnabled(_ stored: Bool?) -> Bool {
        stored ?? defaultEnabled
    }

    /// Splits `app-id=544007664, app-argument=https://example.com/x, affiliate-data=abc` into its pairs.
    /// Keys are lowercased; values keep their text (a value can contain `=`).
    static func fields(from content: String?) -> [String: String] {
        guard let content else { return [:] }
        var result: [String: String] = [:]
        for part in content.split(separator: ",") {
            let piece = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let equals = piece.firstIndex(of: "=") else { continue }
            let key = piece[..<equals].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = piece[piece.index(after: equals)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, result[key] == nil { result[key] = value }
        }
        return result
    }

    /// The app id and argument from the tag, or nil when the tag has no valid numeric app id.
    static func parse(content: String?) -> (appID: String, argument: URL?)? {
        let values = fields(from: content)
        guard let id = values["app-id"], !id.isEmpty, id.count <= 15, id.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }
        var argument: URL?
        if let raw = values["app-argument"], let url = URL(string: raw),
           ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
            argument = url
        }
        return (id, argument)
    }

    /// The banner for a page, or nil when the page has no usable tag. An argument on another site is dropped, so a
    /// page can only point the banner at its own site.
    static func info(from page: PageInfo?, pageURL: URL?) -> AppBannerInfo? {
        guard let page, let parsed = parse(content: page.banner),
              let pageURL, ["http", "https"].contains(pageURL.scheme?.lowercased() ?? ""),
              let host = pageURL.host, !host.isEmpty else { return nil }
        var argument = parsed.argument
        if let candidate = argument, !sameSite(candidate.host, host) { argument = nil }
        return AppBannerInfo(
            appID: parsed.appID,
            argument: argument,
            appName: appName(title: page.title, host: host),
            hostKey: hostKey(host)
        )
    }

    /// Lowercased host without www, m, or mobile in front.
    static func hostKey(_ host: String?) -> String {
        var value = (host ?? "").lowercased()
        for prefix in ["www.", "m.", "mobile."] where value.hasPrefix(prefix) && value.count > prefix.count {
            value = String(value.dropFirst(prefix.count))
        }
        return value
    }

    /// The site part of a host: the last two labels, or three for names like example.co.uk.
    static func siteLabel(_ host: String?) -> String {
        let labels = hostKey(host).split(separator: ".").map(String.init)
        guard labels.count > 2 else { return labels.joined(separator: ".") }
        let secondLevel: Set<String> = ["co", "com", "org", "net", "gov", "edu", "ac"]
        let take = (labels[labels.count - 1].count == 2 && secondLevel.contains(labels[labels.count - 2])) ? 3 : 2
        return labels.suffix(take).joined(separator: ".")
    }

    static func sameSite(_ a: String?, _ b: String?) -> Bool {
        let left = siteLabel(a)
        return !left.isEmpty && left == siteLabel(b)
    }

    /// A readable app name. If a piece of the page title matches the site name, that piece is used with its own
    /// capitalization (YouTube). Otherwise the site name, capitalized.
    static func appName(title: String, host: String) -> String {
        let site = siteLabel(host)
        let label = site.split(separator: ".").first.map(String.init) ?? site
        guard !label.isEmpty else { return host }
        let separators: Set<Character> = ["-", "|", ":", "\u{00B7}", "\u{2022}"]
        let pieces = title.split(whereSeparator: { separators.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let match = pieces.first(where: { $0.lowercased() == label.lowercased() }) {
            return match
        }
        return label.prefix(1).uppercased() + label.dropFirst()
    }

    /// The address to hand to the system. The tag's argument when it has one, else the page itself.
    static func openURL(for info: AppBannerInfo, pageURL: URL?) -> URL? {
        if let argument = info.argument { return argument }
        guard let pageURL, ["http", "https"].contains(pageURL.scheme?.lowercased() ?? "") else { return nil }
        return pageURL
    }
}

/// Hosts whose banner was dismissed. Lives in memory only: it is gone when Zalla closes, and private tabs keep
/// a separate list so they never touch normal browsing.
struct AppBannerDismissals: Equatable {
    private(set) var hosts: Set<String> = []

    func isDismissed(_ hostKey: String) -> Bool {
        hosts.contains(hostKey)
    }

    mutating func dismiss(_ hostKey: String) {
        guard !hostKey.isEmpty else { return }
        hosts.insert(hostKey)
    }

    mutating func reset() {
        hosts = []
    }
}
