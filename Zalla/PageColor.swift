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
    /// The color painted at the top edge of the viewport, as the page script saw it by looking at what sits there.
    var edgeBackground: String? = nil
    /// True once the page has finished loading. Early reads of a page still loading can be wrong (no styles yet).
    var ready: Bool = true

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
            title: text("title") ?? "",
            edgeBackground: text("edge"),
            ready: dictionary["ready"] as? Bool ?? true
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

    /// The color for the status bar area, in order: what is actually painted at the top edge of the viewport, the
    /// page's theme-color (the script already picks the one that matches dark mode), the body background, the html
    /// background, and finally white (a page that paints nothing shows the white canvas).
    static func sample(from info: PageInfo) -> PageRGB {
        opaque(info.edgeBackground) ?? opaque(info.themeColor) ?? opaque(info.bodyBackground)
            ?? opaque(info.htmlBackground) ?? canvas
    }

    /// True when the page gave nothing usable: no top edge color, no theme-color, no body or html background.
    static func isWeak(_ info: PageInfo) -> Bool {
        opaque(info.edgeBackground) == nil && opaque(info.themeColor) == nil
            && opaque(info.bodyBackground) == nil && opaque(info.htmlBackground) == nil
    }

    /// The color to keep after a new read. A page still loading that shows nothing usable yet (no styles) would
    /// read as the white canvas, so it is ignored and the previous color stays until a real sample arrives.
    static func next(current: PageRGB?, info: PageInfo) -> PageRGB? {
        if isWeak(info) && !info.ready { return current }
        return sample(from: info)
    }

    /// Whether two colors differ enough to be worth repainting and animating. Tiny shifts (a fading header, a
    /// gradient under a scroll) are ignored so the strip does not shimmer.
    static let visibleThreshold = 0.012

    static func differs(_ a: PageRGB?, _ b: PageRGB?, threshold: Double = PageColor.visibleThreshold) -> Bool {
        guard let a, let b else { return (a == nil) != (b == nil) }
        return max(abs(a.red - b.red), abs(a.green - b.green), abs(a.blue - b.blue)) > threshold
    }

    // MARK: - Text color with hysteresis

    /// Luminance below which a strip is clearly dark, and above which it is clearly light. In between, the previous
    /// choice stays, so a strip near mid gray does not flip the clock text back and forth.
    static let darkBelow = 0.14
    static let lightAbove = 0.22

    /// True when the clock and battery should be light (the strip is dark).
    static func isDark(_ color: PageRGB, previous: Bool?) -> Bool {
        let value = color.luminance
        if value < darkBelow { return true }
        if value > lightAbove { return false }
        return previous ?? color.prefersLightText
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
        appearance: String,
        isDark: Bool? = nil
    ) -> StatusBarPlan {
        guard immersive, hasPage else { return StatusBarPlan(fill: .none, schemeOverride: nil) }
        guard matchPage, let sample else { return StatusBarPlan(fill: .fallback, schemeOverride: nil) }
        // `isDark` carries the hysteresis choice; without it the plain luminance rule applies.
        let pageIsDark = isDark ?? sample.prefersLightText
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

    /// Reads what is painted at the top edge of the viewport (the elements at a few points just below y = 0, walking
    /// up to the first background that paints), the theme-color meta tag (honoring its media query), the body and html
    /// backgrounds, and the apple-itunes-app meta tag, then posts them to Zalla. It re-reads after load, on scroll
    /// (at most about every 100 ms, with a trailing read), on resize, on page changes, and when the color scheme
    /// changes, and only posts when something visibly changed. It never loads anything.
    static let script = #"""
    (function() {
      if (window.__zallaPageInfo) return;
      window.__zallaPageInfo = true;
      var pending = null;
      var trailing = null;
      var frame = 0;
      var lastRun = 0;
      var last = '';
      var lastEdge = null;
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
      function style(el) {
        try { return el ? window.getComputedStyle(el) : null; } catch (e) { return null; }
      }
      function bg(el) {
        var cs = style(el);
        return cs ? cs.backgroundColor : '';
      }
      function htmlBg() {
        var c = bg(document.documentElement);
        var ch = channels(c);
        if (!ch || ch[3] < 0.9) {
          var cs = style(document.documentElement);
          var scheme = cs && cs.colorScheme ? cs.colorScheme : '';
          if (scheme.indexOf('dark') >= 0 && scheme.indexOf('light') < 0) return 'rgb(18, 18, 18)';
        }
        return c;
      }
      function banner() {
        var m = document.querySelector('meta[name="apple-itunes-app"]');
        return m ? m.getAttribute('content') : null;
      }
      function channels(c) {
        if (!c) return null;
        var m = c.match(/[0-9.]+/g);
        if (!m || m.length < 3) return null;
        var a = 1;
        if (m.length > 3) {
          a = parseFloat(m[3]);
          if (c.indexOf('%') >= 0 || a > 1) a = a / 100;
        }
        return [parseFloat(m[0]), parseFloat(m[1]), parseFloat(m[2]), a];
      }
      // The color painted at one point: a CSS color string, '' when an image or gradient (or an unreadable color)
      // sits there, or null when nothing paints and the page canvas shows through.
      function paintAt(x, y) {
        var node = document.elementFromPoint(x, y);
        var steps = 0;
        while (node && node.nodeType === 1 && steps++ < 40) {
          var cs = style(node);
          if (cs) {
            var image = cs.backgroundImage;
            if (image && image !== 'none') return '';
            var c = cs.backgroundColor;
            var ch = channels(c);
            if (ch && ch[3] >= 0.9) return c;
            if (!ch && c && c !== 'transparent') return '';
          }
          node = node.parentElement;
        }
        return null;
      }
      function edge() {
        try {
          var w = window.innerWidth || document.documentElement.clientWidth;
          if (!w) return null;
          var fractions = [0.5, 0.25, 0.75, 0.1, 0.9];
          var counts = {};
          var best = null;
          var bestCount = 0;
          for (var i = 0; i < fractions.length; i++) {
            var c = paintAt(Math.round(w * fractions[i]), 1);
            if (!c) continue;
            counts[c] = (counts[c] || 0) + 1;
            if (counts[c] > bestCount) { best = c; bestCount = counts[c]; }
          }
          return best;
        } catch (e) { return null; }
      }
      function same(a, b) {
        if (!a || !b) return a === b;
        return Math.abs(a[0] - b[0]) < 6 && Math.abs(a[1] - b[1]) < 6 && Math.abs(a[2] - b[2]) < 6;
      }
      function send() {
        var e = edge();
        var ec = channels(e);
        var payload = {
          theme: theme(), body: bg(document.body), html: htmlBg(), edge: e,
          banner: banner(), title: document.title || '', ready: document.readyState === 'complete'
        };
        var rest = JSON.stringify([payload.theme, payload.body, payload.html, payload.banner, payload.title, payload.ready]);
        if (rest === last && same(ec, lastEdge)) return;
        last = rest;
        lastEdge = ec;
        try { window.webkit.messageHandlers.zallaPageInfo.postMessage(payload); } catch (x) {}
      }
      function soon(ms) {
        if (pending) return;
        pending = setTimeout(function() { pending = null; send(); }, ms);
      }
      function onScroll() {
        var now = Date.now();
        if (!frame && now - lastRun >= 100) {
          frame = requestAnimationFrame(function() { frame = 0; lastRun = Date.now(); send(); });
        }
        if (trailing) clearTimeout(trailing);
        trailing = setTimeout(function() { trailing = null; lastRun = Date.now(); send(); }, 120);
      }
      send();
      document.addEventListener('DOMContentLoaded', function() { soon(30); });
      window.addEventListener('load', function() { soon(50); setTimeout(send, 900); });
      window.addEventListener('pageshow', function() { soon(50); });
      window.addEventListener('scroll', onScroll, { passive: true });
      window.addEventListener('resize', function() { soon(100); });
      window.addEventListener('orientationchange', function() { soon(200); });
      document.addEventListener('transitionend', function() { soon(80); }, true);
      try {
        var observer = new MutationObserver(function() { soon(150); });
        if (document.head) observer.observe(document.head, { childList: true, subtree: true, attributes: true, attributeFilter: ['content', 'media'] });
        if (document.body) observer.observe(document.body, { childList: true, attributes: true, attributeFilter: ['class', 'style'] });
        observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class', 'style', 'data-theme', 'dark'] });
      } catch (e) {}
      try { window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function() { soon(100); }); } catch (e) {}
      // Single page apps move headers around without any event we can rely on, so check now and then while visible.
      setInterval(function() { if (document.visibilityState === 'visible') send(); }, 1000);
    })();
    """#
}
