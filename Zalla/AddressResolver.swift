import Foundation

enum SearchEngine: String, CaseIterable, Codable {
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case bing = "Bing"

    var endpoint: String {
        switch self {
        case .duckDuckGo: return "https://duckduckgo.com/"
        case .google: return "https://www.google.com/search"
        case .bing: return "https://www.bing.com/search"
        }
    }
}

enum AddressResolver {
    static func resolve(_ input: String, engine: SearchEngine) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["https", "http"].contains(scheme), url.host != nil {
            return url
        }
        if !text.contains(where: { $0.isWhitespace }), !text.contains("://"),
           let url = URL(string: "https://" + text),
           let host = url.host, host.contains("."), url.user == nil, url.password == nil {
            return url
        }
        var components = URLComponents(string: engine.endpoint)
        components?.queryItems = [URLQueryItem(name: "q", value: text)]
        // Search providers commonly decode '+' as a space in query strings.
        components?.percentEncodedQuery = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components?.url
    }
}
