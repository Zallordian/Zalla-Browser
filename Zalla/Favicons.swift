import SwiftUI
import UIKit
import CryptoKit

/// Build 48: site icons for tabs, bookmarks, and history. Before this build Zalla drew a generic globe everywhere.
/// After a page loads, a small script reads the page's own icon links (link rel icon, apple-touch-icon, and the web
/// app manifest). Zalla fetches the best one straight from the site, never through a third party favicon service,
/// and keeps a small copy per host on this device. Private tabs fetch and keep nothing. Burn It All clears the cache.
enum FaviconPicker {
    /// One icon the page declares.
    struct Candidate: Equatable {
        var url: URL
        /// Largest side in pixels from the sizes attribute, 0 when unknown.
        var size: Int
        var isTouchIcon: Bool
        var isSVG: Bool
    }

    /// Reads "32x32", "16x16 32x32", or "any". "any" usually means SVG, which counts as unknown.
    static func largestSide(_ sizes: String?) -> Int {
        guard let sizes else { return 0 }
        return sizes.lowercased().split(separator: " ").compactMap { token -> Int? in
            let parts = token.split(separator: "x")
            guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) else { return nil }
            return max(w, h)
        }.max() ?? 0
    }

    static func isSVG(url: URL, type: String?) -> Bool {
        (type?.lowercased().contains("svg") ?? false) || url.pathExtension.lowercased() == "svg"
            || url.absoluteString.lowercased().hasPrefix("data:image/svg")
    }

    /// Builds candidates from what the page script returned: [["href": ..., "rel": ..., "sizes": ..., "type": ...]].
    static func candidates(from links: [[String: String]], pageURL: URL) -> [Candidate] {
        links.compactMap { link in
            guard let href = link["href"], !href.isEmpty,
                  let url = URL(string: href, relativeTo: pageURL)?.absoluteURL,
                  let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
            let rel = (link["rel"] ?? "").lowercased()
            return Candidate(
                url: upgraded(url, pageURL: pageURL),
                size: largestSide(link["sizes"]),
                isTouchIcon: rel.contains("apple-touch-icon"),
                isSVG: isSVG(url: url, type: link["type"])
            )
        }
    }

    /// An http icon on an https page is fetched over https.
    static func upgraded(_ url: URL, pageURL: URL) -> URL {
        guard url.scheme?.lowercased() == "http", pageURL.scheme?.lowercased() == "https",
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        parts.scheme = "https"
        return parts.url ?? url
    }

    /// The order to try: raster icons first, largest first (touch icons count as 180 when unsized),
    /// then /favicon.ico at the site root. SVG goes last, since it can't be drawn as a small image here.
    static func ordered(_ candidates: [Candidate], pageURL: URL) -> [URL] {
        func score(_ c: Candidate) -> Int { c.size > 0 ? c.size : (c.isTouchIcon ? 180 : 32) }
        let raster = candidates.filter { !$0.isSVG }.sorted { score($0) > score($1) }.map(\.url)
        var result: [URL] = []
        for url in raster where !result.contains(url) { result.append(url) }
        if let root = rootFavicon(for: pageURL), !result.contains(root) { result.append(root) }
        for c in candidates where c.isSVG && !result.contains(c.url) { result.append(c.url) }
        return Array(result.prefix(6))
    }

    static func rootFavicon(for pageURL: URL) -> URL? {
        guard let host = pageURL.host, !host.isEmpty else { return nil }
        var parts = URLComponents()
        parts.scheme = pageURL.scheme?.lowercased() == "http" ? "http" : "https"
        parts.host = host
        parts.port = pageURL.port
        parts.path = "/favicon.ico"
        return parts.url
    }

    /// The cache key: the host without a leading www, lowercased.
    static func key(for host: String?) -> String? {
        guard var host = host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    /// Letter for the tile shown before a site's icon is known: the first letter or digit of the main name.
    static func letter(for host: String?) -> String {
        guard let key = key(for: host) else { return "?" }
        let first = key.split(separator: ".").first.map(String.init) ?? key
        return first.first(where: { $0.isLetter || $0.isNumber }).map { String($0).uppercased() } ?? "?"
    }

    /// Reads icons from the manifest JSON: {"icons": [{"src", "sizes", "type"}]}.
    static func manifestLinks(_ data: Data) -> [[String: String]] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let icons = object["icons"] as? [[String: Any]] else { return [] }
        return icons.compactMap { icon in
            guard let src = icon["src"] as? String else { return nil }
            var link = ["href": src, "rel": "manifest"]
            if let sizes = icon["sizes"] as? String { link["sizes"] = sizes }
            if let type = icon["type"] as? String { link["type"] = type }
            return link
        }
    }

    /// Runs in the page after it loads. Reads only the page's own link tags.
    static let script = """
    (function() {
      var out = [];
      var links = document.querySelectorAll('link[rel]');
      for (var i = 0; i < links.length && out.length < 24; i++) {
        var l = links[i];
        var rel = (l.getAttribute('rel') || '').toLowerCase();
        if (rel.indexOf('icon') === -1 && rel !== 'manifest') continue;
        out.push({ href: l.href || '', rel: rel, sizes: l.getAttribute('sizes') || '', type: l.getAttribute('type') || '' });
      }
      return out;
    })();
    """
}

/// The on device icon cache. Memory first, then a small PNG per host in Caches.
@MainActor
final class FaviconStore: ObservableObject {
    static let shared = FaviconStore()

    @Published private(set) var revision = 0
    private var memory: [String: UIImage] = [:]
    private var inFlight: Set<String> = []
    private var lastFetch: [String: Date] = [:]
    let directory: URL
    /// Icons are refreshed at most once a day per host.
    static let refreshInterval: TimeInterval = 24 * 60 * 60
    static let maxBytes = 512 * 1024
    static let side: CGFloat = 64

    init(directory: URL? = nil) {
        self.directory = directory ?? (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("Favicons", isDirectory: true)
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(digest.prefix(32)).png")
    }

    func image(for host: String?) -> UIImage? {
        guard let key = FaviconPicker.key(for: host) else { return nil }
        if let cached = memory[key] { return cached }
        if let data = try? Data(contentsOf: fileURL(for: key)), let image = UIImage(data: data) {
            memory[key] = image
            return image
        }
        return nil
    }

    func store(_ image: UIImage, for key: String) {
        memory[key] = image
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let png = image.pngData() { try? png.write(to: fileURL(for: key), options: .atomic) }
        revision += 1
    }

    func removeAll() {
        memory.removeAll()
        lastFetch.removeAll()
        try? FileManager.default.removeItem(at: directory)
        revision += 1
    }

    /// Called after a page loads in a regular tab. Private tabs never get here.
    func update(pageURL: URL, links: [[String: String]]) {
        guard let key = FaviconPicker.key(for: pageURL.host), !inFlight.contains(key) else { return }
        if let last = lastFetch[key], Date().timeIntervalSince(last) < Self.refreshInterval, memory[key] != nil { return }
        inFlight.insert(key)
        lastFetch[key] = Date()
        Task {
            var all = links
            if let manifest = links.first(where: { $0["rel"] == "manifest" })?["href"],
               let manifestURL = URL(string: manifest, relativeTo: pageURL)?.absoluteURL,
               let data = await download(manifestURL) {
                all += FaviconPicker.manifestLinks(data).map { link in
                    var l = link
                    l["href"] = URL(string: link["href"] ?? "", relativeTo: manifestURL)?.absoluteString ?? ""
                    return l
                }
            }
            let iconLinks = all.filter { $0["rel"] != "manifest" || $0["sizes"] != nil || $0["type"] != nil }
            let order = FaviconPicker.ordered(FaviconPicker.candidates(from: iconLinks, pageURL: pageURL), pageURL: pageURL)
            for url in order {
                guard let data = await download(url), let image = Self.decode(data) else { continue }
                store(image, for: key)
                break
            }
            inFlight.remove(key)
        }
    }

    /// Follows redirects (URLSession does by default) and gives up on anything too big or not an image.
    private func download(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue("image/png,image/x-icon,image/webp,image/jpeg,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")
        guard let result = try? await session.data(for: request) else { return nil }
        let data = result.0
        guard let http = result.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              data.count > 0, data.count <= Self.maxBytes else { return nil }
        return data
    }

    /// PNG, ICO, JPEG, GIF, and WebP decode natively. SVG does not, so it simply fails and the next one is tried.
    static func decode(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data), image.size.width >= 8, image.size.height >= 8 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}

/// A site's icon, or a letter tile in the accent color when Zalla hasn't seen the site yet.
struct FaviconView: View {
    let host: String?
    var size: CGFloat = 20
    var isPrivate = false
    @ObservedObject private var store = FaviconStore.shared

    var body: some View {
        let _ = store.revision
        Group {
            if !isPrivate, let image = store.image(for: host) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18))
                    .overlay {
                        Text(isPrivate ? "" : FaviconPicker.letter(for: host))
                            .font(.system(size: size * 0.55, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                    }
                    .overlay {
                        if isPrivate {
                            Image(systemName: "eye.slash").font(.system(size: size * 0.5)).foregroundStyle(Color.accentColor)
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .accessibilityHidden(true)
    }
}
