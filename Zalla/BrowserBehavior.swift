import Foundation

/// Swipe from the screen edge to go back or forward. On by default, one switch in Settings.
enum SwipeNavigation {
    static let storageKey = "swipeNavigation"

    static var isEnabled: Bool { enabled(in: .standard) }

    static func enabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? true
    }
}

/// Per-site "request desktop site" choices. A site you switch to desktop stays that way next time.
enum DesktopSitePreference {
    static let storageKey = "desktopSiteHosts"

    static func hosts(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    static func key(for url: URL?) -> String? {
        guard var host = HTTPSOnly.normalizedHost(url?.host) else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    static func isDesktop(_ url: URL?, in defaults: UserDefaults = .standard) -> Bool {
        guard let key = key(for: url) else { return false }
        return hosts(in: defaults).contains(key)
    }

    static func set(_ desktop: Bool, for url: URL?, in defaults: UserDefaults = .standard) {
        guard let key = key(for: url) else { return }
        var current = hosts(in: defaults)
        if desktop { current.insert(key) } else { current.remove(key) }
        defaults.set(current.sorted(), forKey: storageKey)
    }
}

/// Turns an address handed to Zalla by another app into a page to open.
enum IncomingLink {
    /// Web addresses open as they are. `zalla://open?url=<address>` opens the address inside it. Only http and https targets are ever opened.
    static func webURL(from url: URL) -> URL? {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "http" || scheme == "https" {
            return (url.host ?? "").isEmpty ? nil : url
        }
        guard scheme == "zalla",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let target = URL(string: raw),
              let targetScheme = target.scheme?.lowercased(),
              targetScheme == "http" || targetScheme == "https",
              !(target.host ?? "").isEmpty else { return nil }
        return target
    }
}
