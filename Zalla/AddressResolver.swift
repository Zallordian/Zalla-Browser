import Foundation

enum SearchEngine: String, CaseIterable, Codable {
    // Raw values are stored in settings, so the first three keep their original names.
    case google = "Google"
    case bing = "Bing"
    case duckDuckGo = "DuckDuckGo"
    case brave = "Brave Search"
    case startpage = "Startpage"
    case ecosia = "Ecosia"
    case kagi = "Kagi"
    case custom = "Custom URL"

    static let storageKey = "searchEngine"
    static let customTemplateKey = "customSearchURL"
    /// Brave Search is the default for new installs and resets.
    static let defaultEngine = SearchEngine.brave

    /// In-app search URL template. Always https and loaded inside WKWebView.
    var endpoint: String {
        switch self {
        case .google: return "https://www.google.com/search"
        case .bing: return "https://www.bing.com/search"
        case .duckDuckGo: return "https://duckduckgo.com/"
        case .brave: return "https://search.brave.com/search"
        case .startpage: return "https://www.startpage.com/sp/search"
        case .ecosia: return "https://www.ecosia.org/search"
        case .kagi: return "https://kagi.com/search"
        case .custom: return SearchEngine.brave.endpoint
        }
    }

    var queryParameter: String {
        self == .startpage ? "query" : "q"
    }

    /// Name shown in pickers. Kagi needs a paid Kagi account, so it is tagged.
    var displayName: String {
        self == .kagi ? "Kagi (Paid)" : rawValue
    }

    /// Engines to offer in a picker. Custom URL only shows once a usable address is saved (or is already chosen).
    static func choices(customTemplate: String?, selected: SearchEngine? = nil) -> [SearchEngine] {
        allCases.filter { engine in
            engine != .custom || selected == .custom || customURLTemplate(from: customTemplate) != nil
        }
    }

    /// A usable Custom URL address: http or https, with %s where the search goes.
    static func customURLTemplate(from raw: String?) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.contains("%s"),
              let url = URL(string: text.replacingOccurrences(of: "%s", with: "test")),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              url.host != nil else { return nil }
        return text
    }

    static let defaultMigratedKey = "searchEngineDefaultMigrated"

    /// Runs once. People who finished setup before Brave became the default and never picked an engine
    /// were searching with DuckDuckGo, so that stays their choice. New installs (setup not finished
    /// yet) and resets get Brave Search.
    static func keepExistingChoice(in defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: defaultMigratedKey) else { return }
        defaults.set(true, forKey: defaultMigratedKey)
        guard defaults.string(forKey: storageKey) == nil,
              defaults.bool(forKey: "hasCompletedOnboarding") else { return }
        defaults.set(SearchEngine.duckDuckGo.rawValue, forKey: storageKey)
    }
}

enum AddressResolver {
    /// Resolves typed input to an https/http URL suitable for in-app WKWebView loading.
    /// Search queries become engine result pages. Never returns app-scheme or file URLs.
    static func resolve(_ input: String, engine: SearchEngine, customTemplate: String? = nil) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["https", "http"].contains(scheme), url.host != nil {
            return url
        }

        // Bare domains become https navigations. Anything with spaces or without a dot goes to search.
        if looksLikeDomain(text),
           let url = URL(string: "https://" + text),
           let host = url.host, host.contains("."),
           url.user == nil, url.password == nil {
            return url
        }

        // Searches that are clearly local get the saved city when that setting is on.
        return searchURL(for: LocalSearch.augmentedForCurrentSettings(text), engine: engine, customTemplate: customTemplate)
    }

    /// Builds a search-results URL for the chosen engine (always in-app).
    static func searchURL(for query: String, engine: SearchEngine, customTemplate: String? = nil) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if engine == .custom {
            if let template = SearchEngine.customURLTemplate(from: customTemplate) {
                return customSearchURL(template: template, query: trimmed)
            }
            return searchURL(for: trimmed, engine: SearchEngine.defaultEngine)
        }
        var components = URLComponents(string: engine.endpoint)
        components?.queryItems = [URLQueryItem(name: engine.queryParameter, value: trimmed)]
        // Search providers commonly decode '+' as a space in query strings.
        if let encodedQuery = components?.percentEncodedQuery {
            components?.percentEncodedQuery = encodedQuery.replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components?.url,
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              url.host != nil else {
            return nil
        }
        return url
    }

    /// Puts the encoded query where %s is in a Custom URL address.
    private static func customSearchURL(template: String, query: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=#?/%;")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: template.replacingOccurrences(of: "%s", with: encoded)),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }

    private static func looksLikeDomain(_ text: String) -> Bool {
        if text.contains(where: { $0.isWhitespace }) { return false }
        if text.contains("://") { return false }
        // Reject credentials-looking or scheme-like tokens.
        let lowered = text.lowercased()
        if lowered.hasPrefix("javascript:") || lowered.hasPrefix("data:") || lowered.hasPrefix("file:") {
            return false
        }
        return true
    }
}
