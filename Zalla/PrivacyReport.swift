import Foundation

/// A plain record of what Zalla did for you. Every number here is something Zalla actually did and counted itself.
/// Zalla does not get a running total from the content blocker, so there is no "trackers blocked" figure to show,
/// and none is made up. Third-party connections are measured from the page itself, and labeled as such.
/// Nothing leaves the device, and private tabs are never recorded.
enum PrivacyReport {
    enum Event: String, CaseIterable {
        case linkCleaned
        case httpsUpgrade
        case cookieBannerDismissed
    }

    static let storageKey = "privacyReportCounts"
    static let maxHosts = 300

    struct Counts: Codable, Equatable {
        var linkCleaned = 0
        var httpsUpgrade = 0
        var cookieBannerDismissed = 0

        subscript(event: Event) -> Int {
            get {
                switch event {
                case .linkCleaned: return linkCleaned
                case .httpsUpgrade: return httpsUpgrade
                case .cookieBannerDismissed: return cookieBannerDismissed
                }
            }
            set {
                switch event {
                case .linkCleaned: linkCleaned = newValue
                case .httpsUpgrade: httpsUpgrade = newValue
                case .cookieBannerDismissed: cookieBannerDismissed = newValue
                }
            }
        }

        var total: Int { linkCleaned + httpsUpgrade + cookieBannerDismissed }
    }

    struct Store: Codable, Equatable {
        var overall = Counts()
        var byHost: [String: Counts] = [:]
    }

    static func load(from defaults: UserDefaults = .standard) -> Store {
        guard let data = defaults.data(forKey: storageKey),
              let store = try? JSONDecoder().decode(Store.self, from: data) else { return Store() }
        return store
    }

    static func save(_ store: Store, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func record(_ event: Event, host: String?, in defaults: UserDefaults = .standard) {
        var store = load(from: defaults)
        store.overall[event] += 1
        if let key = siteKey(host) {
            if store.byHost[key] == nil, store.byHost.count >= maxHosts { save(store, to: defaults); return }
            store.byHost[key, default: Counts()][event] += 1
        }
        save(store, to: defaults)
    }

    static func counts(forHost host: String?, in defaults: UserDefaults = .standard) -> Counts {
        guard let key = siteKey(host) else { return Counts() }
        return load(from: defaults).byHost[key] ?? Counts()
    }

    static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    /// Forgets which sites the counts belong to but keeps the overall totals. Used by Burn It All and Clear Browsing Data.
    static func clearHosts(in defaults: UserDefaults = .standard) {
        var store = load(from: defaults)
        store.byHost = [:]
        save(store, to: defaults)
    }

    /// Host without www, lowercased.
    static func siteKey(_ host: String?) -> String? {
        guard var key = host?.lowercased(), !key.isEmpty else { return nil }
        if key.hasPrefix("www.") { key.removeFirst(4) }
        return key
    }

    /// Hosts in a list of resource addresses that are not the page's own site, without repeats.
    /// "Own site" means the page host or any subdomain of it (or the reverse), a simple test that avoids a public suffix list.
    static func thirdPartyHosts(pageHost: String?, resourceURLs: [String]) -> [String] {
        guard let page = siteKey(pageHost) else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for raw in resourceURLs {
            guard let host = siteKey(URL(string: raw)?.host), !host.isEmpty else { continue }
            if host == page || host.hasSuffix("." + page) || page.hasSuffix("." + host) { continue }
            if sameRegistrableGuess(host, page) { continue }
            if seen.insert(host).inserted { result.append(host) }
        }
        return result
    }

    /// Two hosts that share their last two labels (three for common two-part endings) count as one site.
    static func sameRegistrableGuess(_ a: String, _ b: String) -> Bool {
        registrableGuess(a) == registrableGuess(b)
    }

    static func registrableGuess(_ host: String) -> String {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return host }
        let twoPartEndings: Set<String> = ["co.uk", "org.uk", "ac.uk", "com.au", "co.jp", "co.nz", "com.br", "co.in"]
        let lastTwo = labels.suffix(2).joined(separator: ".")
        let take = twoPartEndings.contains(lastTwo) ? 3 : 2
        return labels.suffix(take).joined(separator: ".")
    }
}
