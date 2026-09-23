import Foundation
import WebKit

enum ReaderMode {
    /// JavaScript that extracts article-like content and returns JSON via completion.
    static let extractScript = """
    (function() {
      function textOf(el) {
        if (!el) return '';
        return (el.innerText || el.textContent || '').replace(/\\s+/g, ' ').trim();
      }
      var title = document.title || '';
      var h1 = document.querySelector('h1');
      if (h1) {
        var h1Text = textOf(h1);
        if (h1Text.length > 0) title = h1Text;
      }
      var byline = '';
      var author = document.querySelector('[rel="author"], .author, .byline, meta[name="author"]');
      if (author) {
        if (author.tagName === 'META') byline = author.getAttribute('content') || '';
        else byline = textOf(author);
      }
      var article = document.querySelector('article') ||
                    document.querySelector('[role="main"]') ||
                    document.querySelector('main') ||
                    document.body;
      var clone = article.cloneNode(true);
      var removeSelectors = [
        'script', 'style', 'noscript', 'iframe', 'nav', 'footer', 'header',
        'aside', 'form', '.ad', '.ads', '.advertisement', '.social',
        '.share', '.comments', '.comment', '[aria-hidden="true"]'
      ];
      removeSelectors.forEach(function(sel) {
        clone.querySelectorAll(sel).forEach(function(n) { n.remove(); });
      });
      var paragraphs = [];
      clone.querySelectorAll('p, h2, h3, h4, li, blockquote, pre').forEach(function(node) {
        var t = textOf(node);
        if (t.length < 2) return;
        var tag = node.tagName.toLowerCase();
        paragraphs.push({ tag: tag, text: t });
      });
      if (paragraphs.length < 2) {
        var raw = textOf(clone);
        if (raw.length > 80) {
          paragraphs = raw.split(/(?<=\\.)\\s+/).filter(function(s) {
            return s.trim().length > 40;
          }).slice(0, 40).map(function(s) {
            return { tag: 'p', text: s.trim() };
          });
        }
      }
      return JSON.stringify({
        title: title,
        byline: byline,
        site: location.hostname || '',
        paragraphs: paragraphs
      });
    })();
    """

    static func buildHTML(
        title: String,
        byline: String,
        site: String,
        paragraphs: [[String: String]],
        dark: Bool
    ) -> String {
        let bg = dark ? "#111111" : "#F7F5F2"
        let fg = dark ? "#F2F2F2" : "#1C1C1E"
        let muted = dark ? "#A0A0A5" : "#6C6C70"
        let accent = "#E33B4F"
        func escape(_ value: String) -> String {
            value
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }
        var body = ""
        for item in paragraphs {
            let tag = item["tag"] ?? "p"
            let text = escape(item["text"] ?? "")
            switch tag {
            case "h2": body += "<h2>\(text)</h2>\n"
            case "h3": body += "<h3>\(text)</h3>\n"
            case "h4": body += "<h4>\(text)</h4>\n"
            case "li": body += "<li>\(text)</li>\n"
            case "blockquote": body += "<blockquote>\(text)</blockquote>\n"
            case "pre": body += "<pre>\(text)</pre>\n"
            default: body += "<p>\(text)</p>\n"
            }
        }
        let bylineBlock: String
        if byline.isEmpty && site.isEmpty {
            bylineBlock = ""
        } else if byline.isEmpty {
            bylineBlock = "<p class=\"byline\">\(escape(site))</p>"
        } else if site.isEmpty {
            bylineBlock = "<p class=\"byline\">\(escape(byline))</p>"
        } else {
            bylineBlock = "<p class=\"byline\">\(escape(byline)) · \(escape(site))</p>"
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>\(escape(title))</title>
        <style>
          :root { color-scheme: \(dark ? "dark" : "light"); }
          body {
            margin: 0 auto;
            padding: 28px 22px 80px;
            max-width: 40rem;
            font: -apple-system-body;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
            background: \(bg);
            color: \(fg);
            line-height: 1.55;
          }
          h1 {
            font-size: 1.75rem;
            line-height: 1.2;
            margin: 0 0 8px;
            letter-spacing: -0.02em;
          }
          .byline {
            color: \(muted);
            font-size: 0.95rem;
            margin: 0 0 24px;
          }
          h2, h3, h4 { margin: 1.4em 0 0.5em; line-height: 1.25; }
          p, li { margin: 0 0 1em; }
          blockquote {
            margin: 1em 0;
            padding-left: 1em;
            border-left: 3px solid \(accent);
            color: \(muted);
          }
          pre {
            overflow-x: auto;
            padding: 12px;
            border-radius: 12px;
            background: \(dark ? "#1C1C1E" : "#EBE7E1");
            font-size: 0.9rem;
          }
          a { color: \(accent); }
        </style>
        </head>
        <body>
          <h1>\(escape(title))</h1>
          \(bylineBlock)
          \(body)
        </body>
        </html>
        """
    }

    struct ExtractedArticle: Equatable {
        var title: String
        var byline: String
        var site: String
        var paragraphs: [[String: String]]
    }

    static func parseExtractedJSON(_ raw: Any?) -> ExtractedArticle? {
        guard let string = raw as? String,
              let data = string.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let title = object["title"] as? String ?? "Article"
        let byline = object["byline"] as? String ?? ""
        let site = object["site"] as? String ?? ""
        let rawParagraphs = object["paragraphs"] as? [[String: Any]] ?? []
        let paragraphs: [[String: String]] = rawParagraphs.compactMap { item in
            guard let text = item["text"] as? String, !text.isEmpty else { return nil }
            let tag = item["tag"] as? String ?? "p"
            return ["tag": tag, "text": text]
        }
        guard !paragraphs.isEmpty else { return nil }
        return ExtractedArticle(title: title, byline: byline, site: site, paragraphs: paragraphs)
    }
}

/// Lightweight back/forward list snapshots for hold-to-reveal and tests.
struct HistoryListItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let host: String
    let url: URL
}

enum HistoryListHelper {
    /// Takes newest-first items and returns at most `limit` entries with stable ids 1...n.
    static func limited(
        _ items: [(title: String, url: URL)],
        limit: Int = 5
    ) -> [HistoryListItem] {
        let capped = Array(items.prefix(max(0, limit)))
        return capped.enumerated().map { index, item in
            HistoryListItem(
                id: index + 1,
                title: item.title.isEmpty ? (item.url.host ?? item.url.absoluteString) : item.title,
                host: item.url.host ?? item.url.absoluteString,
                url: item.url
            )
        }
    }
}
