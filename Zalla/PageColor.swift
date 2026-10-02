import Foundation

/// A color read from a web page, as plain numbers from 0 to 1.
struct PageRGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let white = PageRGB(red: 1, green: 1, blue: 1)
    static let black = PageRGB(red: 0, green: 0, blue: 0)

    /// WCAG relative luminance, 0 (black) to 1 (white).
    var luminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// True when light text reads better on this color than dark text. The two contrast ratios cross at about 0.179.
    var prefersLightText: Bool { luminance < 0.179 }
}

/// What the page told us after it loaded. All fields are raw text from the page.
struct PageInfo: Equatable {
    var themeColor: String?
    var bodyBackground: String?
    var htmlBackground: String?
    /// The content of the page's apple-itunes-app meta tag, if it has one.
    var banner: String?
    var title: String

    /// Reads the message body the page script posts. Anything that is not a dictionary is ignored.
    static func from(_ body: Any) -> PageInfo? {
        guard let dictionary = body as? [String: Any] else { return nil }
        func text(_ key: String) -> String? {
            guard let value = dictionary[key] as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(2000))
        }
        return PageInfo(
            themeColor: text("theme"),
            bodyBackground: text("body"),
            htmlBackground: text("html"),
            banner: text("banner"),
            title: text("title") ?? ""
        )
    }
}

/// Reads page colors and decides how the status bar area should look. Pure, so it is easy to test.
enum PageColor {
    /// Settings, Appearance, "Status bar matches the page". On by default.
    static let storageKey = "statusBarMatchesPage"
    static let defaultEnabled = true
    /// Used when the page was read but paints no background of its own: browsers show white.
    static let canvas = PageRGB.white

    static func isEnabled(_ stored: Bool?) -> Bool {
        stored ?? defaultEnabled
    }

    private static let names: [String: PageRGB] = [
        "white": PageRGB.white,
        "black": PageRGB.black,
        "red": PageRGB(red: 1, green: 0, blue: 0),
        "green": PageRGB(red: 0, green: 0.5, blue: 0),
        "blue": PageRGB(red: 0, green: 0, blue: 1),
        "gray": PageRGB(red: 0.5, green: 0.5, blue: 0.5),
        "grey": PageRGB(red: 0.5, green: 0.5, blue: 0.5),
        "transparent": PageRGB(red: 0, green: 0, blue: 0, alpha: 0)
    ]

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    /// Parses a CSS color: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb()` and `rgba()` (commas or spaces, optional
    /// `/ alpha`), and a few names. Returns nil for anything else.
    static func parse(_ text: String?) -> PageRGB? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else { return nil }
        if raw.hasPrefix("#") { return parseHex(String(raw.dropFirst())) }
        if raw.hasPrefix("rgb") { return parseFunctional(raw) }
        return names[raw]
    }

    private static func parseHex(_ digits: String) -> PageRGB? {
        let characters = Array(digits)
        guard characters.allSatisfy({ $0.isHexDigit }) else { return nil }
        func pair(_ a: Character, _ b: Character) -> Double? {
            guard let value = Int(String([a, b]), radix: 16) else { return nil }
            return Double(value) / 255
        }
        switch characters.count {
        case 3, 4:
            guard let r = pair(characters[0], characters[0]),
                  let g = pair(characters[1], characters[1]),
                  let b = pair(characters[2], characters[2]) else { return nil }
            let a = characters.count == 4 ? (pair(characters[3], characters[3]) ?? 1) : 1
            return PageRGB(red: r, green: g, blue: b, alpha: a)
        case 6, 8:
            guard let r = pair(characters[0], characters[1]),
                  let g = pair(characters[2], characters[3]),
                  let b = pair(characters[4], characters[5]) else { return nil }
            let a = characters.count == 8 ? (pair(characters[6], characters[7]) ?? 1) : 1
            return PageRGB(red: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }

    private static func parseFunctional(_ lower: String) -> PageRGB? {
        guard let open = lower.firstIndex(of: "("), lower.hasSuffix(")") else { return nil }
        let name = String(lower[..<open])
        guard name == "rgb" || name == "rgba" else { return nil }
        let inner = lower[lower.index(after: open)..<lower.index(before: lower.endIndex)]
        let parts = inner.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" }).map { String($0) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        func channel(_ part: String) -> Double? {
            if part.hasSuffix("%") {
                guard let value = Double(part.dropLast()) else { return nil }
                return clamp(value / 100)
            }
            guard let value = Double(part) else { return nil }
            return clamp(value / 255)
        }
        func alphaValue(_ part: String) -> Double? {
            if part.hasSuffix("%") {
                guard let value = Double(part.dropLast()) else { return nil }
                return clamp(value / 100)
            }
            guard let value = Double(part) else { return nil }
            return clamp(value)
        }
        guard let r = channel(parts[0]), let g = channel(parts[1]), let b = channel(parts[2]) else { return nil }
        let a = parts.count == 4 ? alphaValue(parts[3]) : 1
        guard let alpha = a else { return nil }
        return PageRGB(red: r, green: g, blue: b, alpha: alpha)
    }

    /// Only a mostly opaque color can stand in for the page.
    static func opaque(_ text: String?) -> PageRGB? {
        guard let color = parse(text), color.alpha >= 0.9 else { return nil }
        return PageRGB(red: color.red, green: color.green, blue: color.blue)
    }

    /// The color for the status bar area: the page's theme-color if it has one, else the body background, else the
    /// html background, else white (a page that paints nothing shows the white canvas).
    static func sample(from info: PageInfo) -> PageRGB {
        opaque(info.themeColor) ?? opaque(info.bodyBackground) ?? opaque(info.htmlBackground) ?? canvas
    }

    // MARK: - Status bar plan

    enum SchemeChoice: Equatable {
        case light
        case dark
    }

    /// What to paint above the page and which way the status bar text should lean.
    struct StatusBarPlan: Equatable {
        enum Fill: Equatable {
            /// Not in play: the new tab page, or the solid layout.
            case none
            /// Paint the page's own color.
            case page(PageRGB)
            /// Paint the Zalla background (page color unknown, the setting is off, or it would not be legible).
            case fallback
        }
        var fill: Fill
        /// Set while the system appearance is in use and the page color calls for light or dark status bar text.
        var schemeOverride: SchemeChoice?

        /// True when the web view must start below the status bar, so fixed and sticky page elements (a site's
        /// header) sit under the clock instead of beneath the painted strip. Exactly when a strip is painted.
        var startsBelowStatusBar: Bool {
            switch fill {
            case .none: return false
            case .page, .fallback: return true
            }
        }
    }

    /// `appearance` is the Settings value: "System", "Light", or "Dark". An explicit choice is respected, so a page
    /// color that would clash with it falls back to the Zalla background instead of flipping the app.
    static func plan(
        immersive: Bool,
        matchPage: Bool,
        hasPage: Bool,
        sample: PageRGB?,
        appearance: String
    ) -> StatusBarPlan {
        guard immersive, hasPage else { return StatusBarPlan(fill: .none, schemeOverride: nil) }
        guard matchPage, let sample else { return StatusBarPlan(fill: .fallback, schemeOverride: nil) }
        let pageIsDark = sample.prefersLightText
        switch appearance {
        case "Dark":
            return StatusBarPlan(fill: pageIsDark ? .page(sample) : .fallback, schemeOverride: nil)
        case "Light":
            return StatusBarPlan(fill: pageIsDark ? .fallback : .page(sample), schemeOverride: nil)
        default:
            return StatusBarPlan(fill: .page(sample), schemeOverride: pageIsDark ? .dark : .light)
        }
    }

    // MARK: - Page script

    static let messageName = "zallaPageInfo"

    /// Reads the theme-color meta tag (honoring its media query), the body and html background colors, and the
    /// apple-itunes-app meta tag, then posts them to Zalla. It re-reads after the page loads and when the tags,
    /// classes, or color scheme change, and only posts when something changed. It never loads anything.
    static let script = #"""
    (function() {
      if (window.__zallaPageInfo) return;
      window.__zallaPageInfo = true;
      var timer = null;
      var last = '';
      function theme() {
        var metas = document.querySelectorAll('meta[name="theme-color"]');
        for (var i = 0; i < metas.length; i++) {
          var media = metas[i].getAttribute('media');
          var ok = true;
          if (media) { try { ok = window.matchMedia(media).matches; } catch (e) { ok = true; } }
          if (ok && metas[i].content) return metas[i].content;
        }
        return null;
      }
      function bg(el) {
        try { return el ? window.getComputedStyle(el).backgroundColor : ''; } catch (e) { return ''; }
      }
      function banner() {
        var m = document.querySelector('meta[name="apple-itunes-app"]');
        return m ? m.getAttribute('content') : null;
      }
      function send() {
        var payload = {
          theme: theme(), body: bg(document.body), html: bg(document.documentElement),
          banner: banner(), title: document.title || ''
        };
        var key = JSON.stringify(payload);
        if (key === last) return;
        last = key;
        try { window.webkit.messageHandlers.zallaPageInfo.postMessage(payload); } catch (e) {}
      }
      function soon(ms) {
        if (timer) clearTimeout(timer);
        timer = setTimeout(send, ms);
      }
      send();
      window.addEventListener('load', function() { soon(50); setTimeout(send, 900); });
      try {
        var observer = new MutationObserver(function() { soon(250); });
        if (document.head) observer.observe(document.head, { childList: true, subtree: true, attributes: true, attributeFilter: ['content', 'media'] });
        if (document.body) observer.observe(document.body, { attributes: true, attributeFilter: ['class', 'style'] });
        observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class', 'style', 'data-theme', 'dark'] });
      } catch (e) {}
      try { window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function() { soon(100); }); } catch (e) {}
    })();
    """#
}
