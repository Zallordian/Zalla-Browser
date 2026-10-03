import Foundation

/// Rules for the Search action (app icon or widget) putting the cursor in the address bar. The request waits for the
/// screen, because on a cold launch the bar does not exist yet when the link arrives, and it tries again until the
/// keyboard is really up. Foundation only.
enum SearchFocus {
    /// Settings, Tools, Widgets: "Open search with keyboard ready".
    static let storageKey = "searchKeyboardReady"
    static let defaultEnabled = true
    /// A request this old is dropped, so a tab opened later never grabs the keyboard by surprise.
    static let window: TimeInterval = 6
    static let retryNanoseconds: UInt64 = 300_000_000
    static let maxAttempts = 12

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? defaultEnabled
    }

    static func isPending(requestedAt: Date?, now: Date) -> Bool {
        guard let requestedAt else { return false }
        let age = now.timeIntervalSince(requestedAt)
        return age >= 0 && age < window
    }

    /// Ask for the keyboard only while Zalla is active, since an inactive app cannot show it.
    static func shouldAsk(pending: Bool, isActive: Bool) -> Bool { pending && isActive }

    /// The request is done once the field has focus and something really holds the keyboard.
    static func isSatisfied(fieldFocused: Bool, keyboardHolderExists: Bool) -> Bool {
        fieldFocused && keyboardHolderExists
    }
}

/// Things Zalla can do when asked from outside the app: the app icon quick actions (press and hold the icon) and
/// the `zalla://` links the widgets use. Foundation only, so the routing can be tested without UIKit.
enum QuickAction: String, CaseIterable, Equatable {
    case newTab
    case newPrivateTab
    case search
    case bookmarks
    case burn

    static let storageKey = "quickActionsEnabled"
    static let defaultEnabled = true
    /// Prefix of the shortcut types declared in Info.plist (project.yml, UIApplicationShortcutItems).
    static let typePrefix = "com.zalla.browser.quickaction."

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? defaultEnabled
    }

    var shortcutType: String { Self.typePrefix + rawValue }

    var title: String {
        switch self {
        case .newTab: return "New Tab"
        case .newPrivateTab: return "New Private Tab"
        case .search: return "Search"
        case .bookmarks: return "Bookmarks"
        case .burn: return "Burn It All"
        }
    }

    var symbolName: String {
        switch self {
        case .newTab: return "plus"
        case .newPrivateTab: return "eye.slash"
        case .search: return "magnifyingglass"
        case .bookmarks: return "book"
        case .burn: return "flame"
        }
    }

    /// The host of the matching `zalla://` link, for example `zalla://search`.
    var linkHost: String {
        switch self {
        case .newTab: return "new-tab"
        case .newPrivateTab: return "private-tab"
        case .search: return "search"
        case .bookmarks: return "bookmarks"
        case .burn: return "burn"
        }
    }

    var link: URL? { URL(string: "zalla://\(linkHost)") }

    /// What an app icon shortcut does. Returns nil for an unknown type, or for any type while the setting is off.
    static func resolve(shortcutType: String, enabled: Bool) -> QuickAction? {
        guard enabled, shortcutType.hasPrefix(typePrefix) else { return nil }
        return QuickAction(rawValue: String(shortcutType.dropFirst(typePrefix.count)))
    }

    /// What a `zalla://` action link does. Widgets use these, so they do not depend on the icon quick action setting.
    /// `zalla://open?url=...` is not an action, it is a web address and is handled by `IncomingLink`.
    static func resolve(url: URL) -> QuickAction? {
        guard url.scheme?.lowercased() == "zalla", let host = url.host?.lowercased() else { return nil }
        return allCases.first { $0.linkHost == host }
    }

    /// The step the browser takes. Burn only ever asks first, it never burns on its own.
    enum Step: Equatable {
        case newTab
        case newPrivateTab
        case focusAddressBar
        case openLibrary
        case confirmBurn
    }

    var step: Step {
        switch self {
        case .newTab: return .newTab
        case .newPrivateTab: return .newPrivateTab
        case .search: return .focusAddressBar
        case .bookmarks: return .openLibrary
        case .burn: return .confirmBurn
        }
    }

    /// A New Tab action reuses the tab you are on when it is already a blank regular tab, so tapping it twice does
    /// not pile up empty tabs.
    static func reusesCurrentTab(hasSelected: Bool, hasPage: Bool, isPrivate: Bool) -> Bool {
        hasSelected && !hasPage && !isPrivate
    }
}
