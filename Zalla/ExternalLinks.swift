import Foundation
import WebKit

/// Build 50: what a navigation is allowed to do. Pure, so the scheme rules can be tested without a web view.
enum ExternalLinkActivation: Equatable {
    /// A tap on a link, or a form the person submitted.
    case user
    /// A script, a redirect, or anything else WebKit did not count as a tap.
    case script
    /// Back, forward, or reload. Never leaves the browser.
    case history
}

/// The kind of address, before the gesture rules are applied.
enum ExternalLinkKind: Equatable {
    case web
    case document
    case blob
    case data
    case javaScript
    case phone
    case messages
    case mail
    case faceTime
    case maps
    case appStore
    /// An https App Store page, such as apps.apple.com. Stays in the browser unless the person just tapped it.
    case appStorePage
    /// An Android intent:// link. The fallback is a web page, when the link has one.
    case intent(fallback: URL?)
    /// Some other app. `name` is the short label used in "Open in <name>?".
    case app(name: String)
    case blocked
}

/// The question shown before Zalla hands an address to another app.
struct ExternalLinkPrompt: Equatable {
    var url: URL
    var title: String
    /// "Call" for phone numbers, "Open" for everything else. Cancel is always the other button.
    var confirmTitle: String
}

/// What `decidePolicy` should do with one navigation.
enum ExternalLinkDecision: Equatable {
    /// Let WebKit load it (a page, a same-page anchor, or a javascript: link the person tapped).
    case allow
    /// Save the file instead of showing it.
    case download
    /// Ask, then open it in another app.
    case prompt(ExternalLinkPrompt)
    /// Load this web page instead (the fallback inside an Android intent link).
    case load(URL)
    /// A script navigation that might still be the tap we just saw. Check once more in a moment.
    case wait
    /// Drop it. No recent tap, a scheme we never follow, or a prompt we are already showing.
    case cancel
}

/// Everything the scheme rules need, with none of WebKit's types.
struct ExternalLinkContext: Equatable {
    var url: URL
    var currentURL: URL?
    var activation: ExternalLinkActivation = .script
    var gestureFresh: Bool = false
    /// True on the second look, after the short wait for a tap note.
    var gestureSettled: Bool = false
    var wantsDownload: Bool = false
    var isMainFrame: Bool = true
    var hasTargetFrame: Bool = true
    var sourceIsMainFrame: Bool = true
    var targetIsMainFrame: Bool = true
    var method: String = "GET"
    var promptAllowed: Bool = true
}

/// How long a real tap still counts, and which addresses leave the browser.
enum ExternalLinks {
    /// A script that runs right after a tap (Google's Call button) still counts. Longer than this is the page acting alone.
    static let gestureWindow: TimeInterval = 1.5
    /// How long to wait for the tap note to arrive from the page. The note and the navigation race.
    static let gestureGrace: TimeInterval = 0.25
    /// After a prompt is answered, ignore further ones briefly so a page cannot ask again on the same tap.
    static let repeatPause: TimeInterval = 1
    static let gestureMessageName = "zallaTap"
    static var gestureGraceNanoseconds: UInt64 { UInt64(gestureGrace * 1_000_000_000) }

    /// Zalla's own script world. The page's scripts cannot post to the tap handler, so they cannot fake a tap.
    @MainActor static var world: WKContentWorld { .defaultClient }

    static func activation(for type: WKNavigationType) -> ExternalLinkActivation {
        switch type {
        case .linkActivated, .formSubmitted:
            return .user
        case .backForward, .reload, .formResubmitted:
            return .history
        case .other:
            return .script
        @unknown default:
            return .script
        }
    }

    /// "click" is a real click or the keyboard. "touch" is only a finger going down, which also happens while scrolling.
    static func gestureKind(from body: Any) -> ExternalGestureKind? {
        switch body as? String {
        case "click": return .click
        case "touch": return .touch
        default: return nil
        }
    }

    static func kind(of url: URL) -> ExternalLinkKind {
        let scheme = url.scheme?.lowercased() ?? ""
        switch scheme {
        case "http", "https":
            return isAppStorePage(url) ? .appStorePage : .web
        case "about", "applewebdata":
            return .document
        case "blob":
            return .blob
        case "data":
            return .data
        case "javascript":
            return .javaScript
        case "tel", "telprompt":
            return .phone
        case "sms":
            return .messages
        case "mailto":
            return .mail
        case "facetime", "facetime-audio":
            return .faceTime
        case "maps":
            return .maps
        case "itms", "itmss", "itms-apps", "itms-appss":
            return .appStore
        case "intent":
            return .intent(fallback: intentFallback(in: url))
        case "file", "zalla", "ws", "wss", "cid", "":
            return .blocked
        default:
            return .app(name: displayName(for: scheme))
        }
    }

    static func decision(for context: ExternalLinkContext) -> ExternalLinkDecision {
        let kind = kind(of: context.url)
        switch kind {
        case .blob, .data:
            // A blob or data page in a frame is part of the page. The top frame, or a download link, is a file.
            if context.isMainFrame || context.wantsDownload { return .download }
            return .allow
        case .web, .document, .appStorePage:
            if context.wantsDownload, kind == .web || kind == .appStorePage { return .download }
            if isSameDocument(context) { return .allow }
            if kind == .appStorePage {
                if context.activation == .history { return .allow }
                if canPrompt(context) { return .prompt(prompt(for: kind, url: context.url)) }
                if shouldWait(context, forPrompt: true) { return .wait }
                // No tap: show the page. YouTube and Google Maps stay here too, on the .web path.
                return .allow
            }
            return .allow
        case .javaScript:
            if canRunJavaScript(context) { return .allow }
            if shouldWait(context, forPrompt: false) { return .wait }
            return .cancel
        case .intent(let fallback):
            if let fallback, canLeave(context) { return .load(fallback) }
            if shouldWait(context, forPrompt: false) { return .wait }
            return .cancel
        case .phone, .messages, .mail, .faceTime, .maps, .appStore, .app:
            if canPrompt(context) { return .prompt(prompt(for: kind, url: context.url)) }
            if shouldWait(context, forPrompt: true) { return .wait }
            return .cancel
        case .blocked:
            return .cancel
        }
    }

    /// True when only the fragment changed, so the page should jump instead of reloading.
    static func isSameDocument(from current: URL?, to next: URL, method: String, hasTargetFrame: Bool) -> Bool {
        guard hasTargetFrame else { return false }
        let verb = method.uppercased()
        guard verb.isEmpty || verb == "GET" else { return false }
        guard let current, let left = documentKey(current), let right = documentKey(next) else { return false }
        return left == right
    }

    /// The web page named by an Android intent link's `browser_fallback_url`, or nil when there isn't a safe one.
    static func intentFallback(in url: URL) -> URL? {
        guard url.scheme?.lowercased() == "intent" else { return nil }
        // The raw string keeps encoded semicolons inside the fallback. The fragment is already decoded, so try it second.
        if let found = fallbackURL(in: url.absoluteString) { return found }
        if let fragment = url.fragment, let found = fallbackURL(in: fragment) { return found }
        return nil
    }

    static func prompt(for kind: ExternalLinkKind, url: URL) -> ExternalLinkPrompt {
        switch kind {
        case .phone:
            let title = phoneLabel(from: url).map { "Call \($0)?" } ?? "Call this number?"
            return ExternalLinkPrompt(url: url, title: title, confirmTitle: "Call")
        case .messages:
            return ExternalLinkPrompt(url: url, title: "Open in Messages?", confirmTitle: "Open")
        case .mail:
            return ExternalLinkPrompt(url: url, title: "Open in Mail?", confirmTitle: "Open")
        case .faceTime:
            return ExternalLinkPrompt(url: url, title: "Open in FaceTime?", confirmTitle: "Open")
        case .maps:
            return ExternalLinkPrompt(url: url, title: "Open in Maps?", confirmTitle: "Open")
        case .appStore, .appStorePage:
            return ExternalLinkPrompt(url: url, title: "Open in the App Store?", confirmTitle: "Open")
        case .app(let name):
            return ExternalLinkPrompt(url: url, title: "Open in \(name)?", confirmTitle: "Open")
        case .web, .document, .blob, .data, .javaScript, .intent, .blocked:
            return ExternalLinkPrompt(url: url, title: "Open in another app?", confirmTitle: "Open")
        }
    }

    /// Listens for a real tap in every frame and tells Zalla. Synthetic events from the page are ignored.
    static let gestureScript = """
    (function () {
      if (window.__zallaTapNote) return;
      window.__zallaTapNote = true;
      function send(kind, event) {
        if (!event || event.isTrusted !== true) return;
        try { window.webkit.messageHandlers.zallaTap.postMessage(kind); } catch (e) {}
      }
      var opts = { capture: true, passive: true };
      window.addEventListener('pointerdown', function (event) { send('touch', event); }, opts);
      window.addEventListener('touchstart', function (event) { send('touch', event); }, opts);
      window.addEventListener('click', function (event) { send('click', event); }, opts);
      window.addEventListener('keydown', function (event) {
        if (!event || event.isTrusted !== true) return;
        var key = event.key;
        if (key === 'Enter' || key === ' ' || key === 'Spacebar') send('click', event);
      }, opts);
    })();
    """

    // MARK: - Decisions

    /// A recent tap. History never leaves the app. A quiet period does not count here, so a tapped
    /// javascript: link or an intent fallback still runs while another prompt is on cooldown.
    private static func canLeave(_ context: ExternalLinkContext) -> Bool {
        context.activation != .history && context.gestureFresh
    }

    private static func canPrompt(_ context: ExternalLinkContext) -> Bool {
        canLeave(context) && context.promptAllowed
    }

    /// The tap note may still be on its way. A second look or history does not wait. Prompts also skip the
    /// wait while one is showing or just was, so a burst of them is dropped immediately.
    private static func shouldWait(_ context: ExternalLinkContext, forPrompt: Bool) -> Bool {
        guard !context.gestureSettled, context.activation != .history, !context.gestureFresh else { return false }
        if forPrompt && !context.promptAllowed { return false }
        return true
    }

    /// javascript: runs only in the frame that was tapped, and never from an embedded frame into the top page.
    private static func canRunJavaScript(_ context: ExternalLinkContext) -> Bool {
        guard canLeave(context), context.hasTargetFrame else { return false }
        if !context.sourceIsMainFrame && context.targetIsMainFrame { return false }
        return true
    }

    private static func isSameDocument(_ context: ExternalLinkContext) -> Bool {
        isSameDocument(
            from: context.currentURL, to: context.url, method: context.method, hasTargetFrame: context.hasTargetFrame
        )
    }

    // MARK: - Labels

    private struct DocumentKey: Equatable {
        var scheme: String
        var host: String
        var port: Int
        var path: String
        var query: String
    }

    private static func documentKey(_ url: URL) -> DocumentKey? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        var path = url.path
        if path.isEmpty { path = "/" }
        let port = url.port ?? (scheme == "https" ? 443 : 80)
        return DocumentKey(scheme: scheme, host: host, port: port, path: path, query: url.query ?? "")
    }

    private static func isAppStorePage(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host == "appsto.re" || host.hasSuffix(".appsto.re") { return true }
        for root in ["apps.apple.com", "itunes.apple.com"] {
            if host == root || host.hasSuffix("." + root) { return true }
            if host == root + ".cn" || host.hasSuffix("." + root + ".cn") { return true }
        }
        return false
    }

    /// The part after the scheme, without a query. Used only to build a short, safe label.
    private static func payload(_ url: URL) -> String {
        guard let scheme = url.scheme, !scheme.isEmpty else { return "" }
        var rest = url.absoluteString
        let prefix = scheme + ":"
        if rest.lowercased().hasPrefix(prefix.lowercased()) {
            rest.removeFirst(prefix.count)
        }
        if rest.hasPrefix("//") { rest.removeFirst(2) }
        if let cut = rest.firstIndex(where: { $0 == "?" || $0 == "&" || $0 == ";" }) {
            rest = String(rest[..<cut])
        }
        let decoded = rest.removingPercentEncoding ?? rest
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A number safe to show. Anything with letters, a newline, or no digits stays off the dialog.
    private static func phoneLabel(from url: URL) -> String? {
        let raw = payload(url)
        let allowed = CharacterSet(charactersIn: "0123456789+-.() *#")
        guard raw.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              raw.count <= 40,
              raw.contains(where: { $0.isNumber }) else { return nil }
        return raw
    }

    private static let appNames: [String: String] = [
        "music": "Music",
        "musics": "Music",
        "videos": "TV",
        "calshow": "Calendar",
        "webcal": "Calendar",
        "shortcuts": "Shortcuts",
        "shareddocuments": "Files",
        "spotify": "Spotify",
        "whatsapp": "WhatsApp",
        "instagram": "Instagram",
        "twitter": "X",
        "tweetie": "X",
        "fb": "Facebook",
        "facebook": "Facebook",
        "youtube": "YouTube",
        "vnd.youtube": "YouTube",
        "comgooglemaps": "Google Maps",
        "comgooglemaps-x-callback": "Google Maps",
        "googlemaps": "Google Maps",
        "googlegmail": "Gmail",
        "slack": "Slack",
        "zoomus": "Zoom",
        "discord": "Discord",
        "tg": "Telegram",
        "telegram": "Telegram",
        "linkedin": "LinkedIn",
        "snapchat": "Snapchat",
        "tiktok": "TikTok",
        "pinterest": "Pinterest",
        "reddit": "Reddit",
        "paypal": "PayPal",
        "venmo": "Venmo",
        "cashme": "Cash App",
        "squarecash": "Cash App",
        "netflix": "Netflix",
        "twitch": "Twitch",
        "uber": "Uber",
        "lyft": "Lyft",
        "waze": "Waze",
        "imessage": "Messages",
        "message": "Messages",
        "otpauth": "your authenticator",
        "googlechrome": "Chrome",
        "googlechromes": "Chrome",
        "firefox": "Firefox",
        "brave": "Brave",
        "microsoft-edge": "Edge",
        "microsoft-edge-https": "Edge",
        "amzn": "Amazon",
        "amazon": "Amazon"
    ]

    /// A readable app name, or "another app" when the scheme is not a plain word.
    static func displayName(for scheme: String) -> String {
        let key = scheme.lowercased()
        if let known = appNames[key] { return known }
        let letters = CharacterSet.letters
        if key.count >= 2, key.count <= 24, key.unicodeScalars.allSatisfy({ letters.contains($0) }) {
            return key.prefix(1).uppercased() + key.dropFirst()
        }
        return "another app"
    }

    private static func fallbackURL(in source: String) -> URL? {
        let lower = source.lowercased()
        // Case folding can change the length of some letters. Intent links are ASCII, where it does not.
        guard lower.count == source.count else { return nil }
        let keys = ["s.browser_fallback_url=", "browser_fallback_url="]
        guard let key = keys.first(where: { lower.contains($0) }), let range = lower.range(of: key) else { return nil }
        let offset = lower.distance(from: lower.startIndex, to: range.upperBound)
        let start = source.index(source.startIndex, offsetBy: offset)
        var value = String(source[start...])
        if let end = value.firstIndex(of: ";") { value = String(value[..<end]) }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var decoded = value.removingPercentEncoding ?? value
        // Some pages encode the fallback twice.
        if decoded.lowercased().hasPrefix("http%3a") || decoded.lowercased().hasPrefix("https%3a"),
           let again = decoded.removingPercentEncoding {
            decoded = again
        }
        guard let target = URL(string: decoded),
              let scheme = target.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = target.host, !host.isEmpty else { return nil }
        return target
    }
}

enum ExternalGestureKind: Equatable {
    /// A click, or Enter or Space on a focused control.
    case click
    /// A finger going down. Also happens at the start of a scroll.
    case touch
}

/// Remembers the last real tap and whether a prompt is already up. Shared by a popup and the tab that opened it.
final class ExternalGestureClock {
    private var lastTap: Date?
    private var lastKind: ExternalGestureKind?
    private var consumedTap: Date?
    private var promptShowing = false
    /// After the first answer, a finger going down (a scroll) is not enough. A click is.
    private var needsClick = false
    private var quietUntil: Date?

    func note(_ kind: ExternalGestureKind, at time: Date = Date()) {
        // A click that just landed should not be replaced by the touch that belonged to it.
        if kind == .touch, lastKind == .click, let lastTap, time.timeIntervalSince(lastTap) >= 0,
           time.timeIntervalSince(lastTap) < 0.8 {
            return
        }
        lastKind = kind
        lastTap = time
    }

    func isFresh(at time: Date = Date()) -> Bool {
        guard let lastTap else { return false }
        if let consumedTap, lastTap <= consumedTap { return false }
        let age = time.timeIntervalSince(lastTap)
        guard age >= 0, age <= ExternalLinks.gestureWindow else { return false }
        if needsClick, lastKind != .click { return false }
        return true
    }

    func allowsPrompt(at time: Date = Date()) -> Bool {
        if promptShowing { return false }
        if let quietUntil, time < quietUntil { return false }
        return true
    }

    func didShow(at time: Date = Date()) {
        promptShowing = true
        consumedTap = lastTap ?? time
    }

    func didDismiss(at time: Date = Date()) {
        promptShowing = false
        needsClick = true
        quietUntil = time.addingTimeInterval(ExternalLinks.repeatPause)
    }
}
