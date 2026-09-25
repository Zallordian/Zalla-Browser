import CryptoKit
import Foundation

/// A bundled rule list category. Raw values match the ids in blocklists-manifest.json.
enum BlocklistCategory: String, CaseIterable, Codable, Identifiable {
    case trackers = "privacy"
    case commonAds = "ads-basic"
    case fullAds = "ads-extra"
    case adSpaces = "cosmetic"
    case annoyances

    var id: String { rawValue }

    /// Trackers and common ads are free. Everything else needs Zalla Unlock.
    var requiresUnlock: Bool {
        switch self {
        case .trackers, .commonAds:
            return false
        case .fullAds, .adSpaces, .annoyances:
            return true
        }
    }

    var title: String {
        switch self {
        case .trackers: return "Block Trackers"
        case .commonAds: return "Block Common Ads"
        case .fullAds: return "Full Ad Blocking"
        case .adSpaces: return "Hide Ad Spaces"
        case .annoyances: return "Block Cookie Banners and Annoyances"
        }
    }

    var detail: String {
        switch self {
        case .trackers: return "Stops known tracking and analytics requests."
        case .commonAds: return "Stops requests to known ad networks."
        case .fullAds: return "Adds detailed rules for ads that ad network blocking misses."
        case .adSpaces: return "Hides leftover ad boxes and banners on pages."
        case .annoyances: return "Hides cookie consent notices, newsletter popups, and social widgets."
        }
    }

    var systemImage: String {
        switch self {
        case .trackers: return "eye.slash"
        case .commonAds: return "rectangle.slash"
        case .fullAds: return "shield.lefthalf.filled"
        case .adSpaces: return "rectangle.dashed"
        case .annoyances: return "hand.raised.slash"
        }
    }
}

/// blocklists-manifest.json written by tools/blocklists/build_blocklists.py.
struct BlocklistManifest: Decodable {
    struct Part: Decodable, Equatable {
        let name: String
        let resource: String
        let rules: Int
        let version: String
    }

    struct List: Decodable {
        let id: String
        let parts: [Part]
    }

    let lists: [List]

    static func load(from bundle: Bundle = .main) -> BlocklistManifest? {
        guard let url = bundle.url(forResource: "blocklists-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BlocklistManifest.self, from: data)
    }

    func parts(for category: BlocklistCategory) -> [Part] {
        lists.first { $0.id == category.rawValue }?.parts ?? []
    }
}

/// An element hidden with Hide Element, applied to one site and its subdomains.
struct HiddenElementRule: Codable, Equatable, Identifiable {
    var id = UUID()
    var host: String
    var selector: String
}

/// One rule in WebKit's content blocker JSON format.
struct ContentRule: Encodable, Equatable {
    struct Trigger: Encodable, Equatable {
        var urlFilter: String
        var ifDomain: [String]?

        enum CodingKeys: String, CodingKey {
            case urlFilter = "url-filter"
            case ifDomain = "if-domain"
        }
    }

    struct Action: Encodable, Equatable {
        var type: String
        var selector: String?
    }

    var trigger: Trigger
    var action: Action
}

/// Content blocking preferences. Stored as one JSON value in UserDefaults.
struct ContentBlockingSettings: Codable, Equatable {
    static let storageKey = "contentBlockingSettings"
    /// Apple's limit for rules in one compiled list.
    static let ruleLimit = 150_000
    static let selectorsPerRule = 50

    /// Master switch. On by default so trackers and common ads are blocked from the first launch.
    var isEnabled = true
    /// Categories the user turned off.
    var disabledCategories: [String] = []
    /// Sites with blocking turned off, from Blocking on this Site or the allow list.
    var allowedHosts: [String] = []
    /// Extra sites to block everywhere (Zalla Unlock).
    var customBlockedHosts: [String] = []
    /// Elements hidden with Hide Element (Zalla Unlock).
    var hiddenElements: [HiddenElementRule] = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        disabledCategories = try container.decodeIfPresent([String].self, forKey: .disabledCategories) ?? []
        allowedHosts = try container.decodeIfPresent([String].self, forKey: .allowedHosts) ?? []
        customBlockedHosts = try container.decodeIfPresent([String].self, forKey: .customBlockedHosts) ?? []
        hiddenElements = try container.decodeIfPresent([HiddenElementRule].self, forKey: .hiddenElements) ?? []
    }

    // MARK: Persistence

    static func load(from defaults: UserDefaults = .standard) -> ContentBlockingSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(ContentBlockingSettings.self, from: data) else {
            return ContentBlockingSettings()
        }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    // MARK: Hosts

    /// Lowercased host without a leading www, so a choice for www.example.com covers example.com.
    static func hostKey(for url: URL?) -> String? {
        guard var host = HTTPSOnly.normalizedHost(url?.host) else { return nil }
        if host.hasPrefix("www."), host.count > 4 {
            host.removeFirst(4)
        }
        return host
    }

    /// Accepts a domain or a pasted address and returns its host, or nil when it is not a usable domain.
    static func normalizedHost(fromUserInput input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let host = hostKey(for: URL(string: candidate)) else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard host.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              host.contains("."), !host.hasPrefix("."), !host.hasSuffix("."),
              !host.contains("..") else { return nil }
        return host
    }

    /// True when `host` is `domain` or one of its subdomains.
    static func host(_ host: String, isWithin domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }

    func isAllowed(host: String) -> Bool {
        allowedHosts.contains { Self.host(host, isWithin: $0) }
    }

    /// Whether rule lists should be active for a page. Off for local and private network pages,
    /// non-web pages, allowed sites, and when the master switch is off.
    func shouldBlock(url: URL?) -> Bool {
        guard isEnabled, let url,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let normalized = HTTPSOnly.normalizedHost(url.host),
              !HTTPSOnly.isLocalOrPrivate(normalized),
              let key = Self.hostKey(for: url) else { return false }
        return !isAllowed(host: key)
    }

    mutating func setBlocking(_ enabled: Bool, forHost host: String) {
        if enabled {
            allowedHosts.removeAll { Self.host(host, isWithin: $0) }
        } else if !isAllowed(host: host) {
            allowedHosts.append(host)
            allowedHosts.sort()
        }
    }

    @discardableResult
    mutating func addAllowedHost(fromUserInput input: String) -> Bool {
        guard let host = Self.normalizedHost(fromUserInput: input), !allowedHosts.contains(host) else { return false }
        allowedHosts.append(host)
        allowedHosts.sort()
        return true
    }

    @discardableResult
    mutating func addCustomBlock(fromUserInput input: String) -> Bool {
        guard let host = Self.normalizedHost(fromUserInput: input), !customBlockedHosts.contains(host) else { return false }
        customBlockedHosts.append(host)
        customBlockedHosts.sort()
        return true
    }

    // MARK: Categories

    func isOn(_ category: BlocklistCategory) -> Bool {
        !disabledCategories.contains(category.rawValue)
    }

    mutating func set(_ category: BlocklistCategory, on: Bool) {
        disabledCategories.removeAll { $0 == category.rawValue }
        if !on { disabledCategories.append(category.rawValue) }
    }

    /// Bundled lists to compile, in a stable order. Paid lists only with Zalla Unlock.
    func activeCategories(unlocked: Bool) -> [BlocklistCategory] {
        BlocklistCategory.allCases.filter { isOn($0) && (unlocked || !$0.requiresUnlock) }
    }

    /// True when a change from `old` needs different compiled lists, not just different tabs.
    func needsRecompile(comparedTo old: ContentBlockingSettings) -> Bool {
        disabledCategories != old.disabledCategories
            || customBlockedHosts != old.customBlockedHosts
            || hiddenElements != old.hiddenElements
    }

    // MARK: Hidden elements

    static func isAcceptableSelector(_ selector: String) -> Bool {
        let trimmed = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 500
            && !trimmed.contains("{") && !trimmed.contains("}") && !trimmed.contains("\n")
    }

    @discardableResult
    mutating func addHiddenElement(selector: String, host: String) -> Bool {
        let cleaned = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isAcceptableSelector(cleaned), !host.isEmpty,
              !hiddenElements.contains(where: { $0.host == host && $0.selector == cleaned }) else { return false }
        hiddenElements.append(HiddenElementRule(host: host, selector: cleaned))
        return true
    }

    // MARK: Rule generation

    /// url-filter that matches a host and all of its subdomains.
    static func hostFilter(_ host: String) -> String {
        "^[a-z-]+://([^/]+\\.)?" + NSRegularExpression.escapedPattern(for: host) + "[/:]"
    }

    /// The user's own rules: custom blocked sites and hidden elements. Empty without Zalla Unlock.
    func userRules(unlocked: Bool) -> [ContentRule] {
        guard unlocked else { return [] }
        var rules = customBlockedHosts.map { host in
            ContentRule(trigger: .init(urlFilter: Self.hostFilter(host)), action: .init(type: "block"))
        }
        let byHost = Dictionary(grouping: hiddenElements, by: \.host)
        for host in byHost.keys.sorted() {
            let selectors = byHost[host, default: []].map(\.selector)
            for group in Self.split(selectors, limit: Self.selectorsPerRule) {
                rules.append(ContentRule(
                    trigger: .init(urlFilter: ".*", ifDomain: ["*" + host]),
                    action: .init(type: "css-display-none", selector: group.joined(separator: ", "))
                ))
            }
        }
        return rules
    }

    /// Splits rules into lists that each stay within `limit`.
    static func split<T>(_ items: [T], limit: Int = ruleLimit) -> [[T]] {
        guard limit > 0, !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: limit).map { start in
            Array(items[start..<min(start + limit, items.count)])
        }
    }

    static func encoded(_ rules: [ContentRule]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(rules) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Identifiers

    static let identifierPrefix = "zalla."

    /// Compiled lists are cached under their name and content version, so a new build of a list
    /// is compiled once and old versions are removed.
    static func identifier(for part: BlocklistManifest.Part) -> String {
        identifierPrefix + part.name + "." + part.version
    }

    static func userIdentifier(forJSON json: String, index: Int) -> String {
        let digest = SHA256.hash(data: Data(json.utf8))
        let hex = digest.prefix(6).map { String(format: "%02x", $0) }.joined()
        return identifierPrefix + "user\(index)." + hex
    }
}
