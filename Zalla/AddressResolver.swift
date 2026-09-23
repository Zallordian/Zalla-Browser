import Foundation

enum SearchEngine: String, CaseIterable, Codable {
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case bing = "Bing"

    /// In-app search URL template. Always https and loaded inside WKWebView.
    var endpoint: String {
        switch self {
        case .duckDuckGo: return "https://duckduckgo.com/"
        case .google: return "https://www.google.com/search"
        case .bing: return "https://www.bing.com/search"
        }
    }

    var queryParameter: String { "q" }
}

enum AddressResolver {
    /// Resolves typed input to an https/http URL suitable for in-app WKWebView loading.
    /// Search queries become engine result pages. Never returns app-scheme or file URLs.
    static func resolve(_ input: String, engine: SearchEngine) -> URL? {
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

        return searchURL(for: text, engine: engine)
    }

    /// Builds a search-results URL for the chosen engine (always in-app).
    static func searchURL(for query: String, engine: SearchEngine) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
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
