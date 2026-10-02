import Foundation

/// Swipe from the screen edge to go back or forward. On by default, one switch in Settings.
enum SwipeNavigation {
    static let storageKey = "swipeNavigation"

    static var isEnabled: Bool { enabled(in: .standard) }

    static func enabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? true
    }
}

/// The rules for Zalla's own edge swipe: left edge goes back, right edge goes forward. Pure, so it is easy to test.
enum EdgeSwipe {
    enum Side { case left, right }

    /// How far in, in points, a swipe has to travel to count.
    static let commitDistance = 90.0
    /// A quick flick counts after this much travel.
    static let flickDistance = 30.0
    static let flickVelocity = 700.0

    private static func inward(_ value: Double, _ side: Side) -> Double {
        side == .left ? value : -value
    }

    /// 0 at the edge, 1 once the swipe will commit. Drives the little arrow.
    static func progress(translation: Double, side: Side) -> Double {
        min(max(inward(translation, side) / commitDistance, 0), 1)
    }

    static func shouldCommit(translation: Double, velocity: Double, side: Side) -> Bool {
        let distance = inward(translation, side)
        return distance >= commitDistance || (distance >= flickDistance && inward(velocity, side) >= flickVelocity)
    }

    /// Whether a swipe from this side may start right now.
    static func canBegin(side: Side, enabled: Bool, canGoBack: Bool, canGoForward: Bool) -> Bool {
        guard enabled else { return false }
        return side == .left ? canGoBack : canGoForward
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
