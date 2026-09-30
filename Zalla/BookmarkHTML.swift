import Foundation

enum BookmarkHTML {
    /// Parse Netscape Bookmark File Format (Safari / Chrome / Firefox exports).
    static func parse(_ html: String) -> [SavedPage] {
        var pages: [SavedPage] = []
        // Double or single quoted addresses, titles that span lines, and any attribute order.
        let pattern = #"<a\s+[^>]*?href\s*=\s*(?:"([^"]+)"|'([^']+)')[^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }

        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)
        regex.enumerateMatches(in: html, options: [], range: full) { match, _, _ in
            guard let match, match.numberOfRanges >= 4 else { return }
            let hrefRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            guard hrefRange.location != NSNotFound else { return }
            let href = decodeEntities(ns.substring(with: hrefRange)).trimmingCharacters(in: .whitespacesAndNewlines)
            let titleHTML = ns.substring(with: match.range(at: 3))
            let title = stripTags(titleHTML).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: href),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  url.host != nil else { return }
            let display = title.isEmpty ? (url.host ?? href) : title
            pages.append(SavedPage(title: display, url: url))
        }
        return pages
    }

    static func exportHTML(bookmarks: [SavedPage]) -> String {
        var lines: [String] = []
        lines.append("<!DOCTYPE NETSCAPE-Bookmark-file-1>")
        lines.append("<!-- This is an automatically generated file.")
        lines.append("     It will be read and overwritten.")
        lines.append("     DO NOT EDIT! -->")
        lines.append("<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">")
        lines.append("<TITLE>Bookmarks</TITLE>")
        lines.append("<H1>Bookmarks</H1>")
        lines.append("<DL><p>")
        for page in bookmarks {
            let title = escape(page.title)
            let href = escape(page.url.absoluteString)
            let addDate = Int(page.visitedAt.timeIntervalSince1970)
            lines.append("    <DT><A HREF=\"\(href)\" ADD_DATE=\"\(addDate)\">\(title)</A>")
        }
        lines.append("</DL><p>")
        return lines.joined(separator: "\n")
    }

    static func writeTemporaryExport(bookmarks: [SavedPage]) throws -> URL {
        let html = exportHTML(bookmarks: bookmarks)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Zalla-Bookmarks-\(Int(Date().timeIntervalSince1970)).html")
        try html.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private static func stripTags(_ value: String) -> String {
        decodeEntities(value.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression))
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Reads exported bookmark file bytes. Browsers save UTF-8, but older exports can be Latin-1 or UTF-16.
    static func text(from data: Data) -> String? {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
