import Foundation

/// Build 46: the short main Settings screen, iOS Settings style. Each page is one row on the main screen and opens
/// its own screen. Every SettingsRowID lives on exactly one page, and search finds any row from the main screen.
/// Storage keys and defaults are untouched; this only decides where rows are drawn.
enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case appearance
    case toolbarAndTabs
    case homeAndNewTab
    case search
    case privacy
    case websites
    case downloadsAndTools
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .toolbarAndTabs: return "Toolbar and Tabs"
        case .homeAndNewTab: return "Home and New Tab"
        case .search: return "Search"
        case .privacy: return "Privacy and Security"
        case .websites: return "Websites"
        case .downloadsAndTools: return "Downloads and Tools"
        case .about: return "About and Support"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .toolbarAndTabs: return "menubar.rectangle"
        case .homeAndNewTab: return "house.fill"
        case .search: return "magnifyingglass"
        case .privacy: return "hand.raised.fill"
        case .websites: return "globe"
        case .downloadsAndTools: return "arrow.down.circle.fill"
        case .about: return "info.circle.fill"
        }
    }

    /// Tile color name, mapped to a SwiftUI Color in the view so this file stays Foundation only.
    var tileColorName: String {
        switch self {
        case .general: return "gray"
        case .appearance: return "indigo"
        case .toolbarAndTabs: return "orange"
        case .homeAndNewTab: return "green"
        case .search: return "blue"
        case .privacy: return "blue"
        case .websites: return "teal"
        case .downloadsAndTools: return "cyan"
        case .about: return "pink"
        }
    }

    /// Main screen cards, iOS style: a few rows per card.
    static let mainScreenGroups: [[SettingsPage]] = [
        [.general, .appearance, .toolbarAndTabs, .homeAndNewTab],
        [.search, .privacy, .websites],
        [.downloadsAndTools],
        [.about]
    ]

    /// Redesign phase 4: the short line under each page on the main screen, built from the first rows you will see
    /// there so it can't name something the page doesn't have.
    var contentsLine: String {
        var titles: [String] = []
        for row in shownMainRows where row.kind != .destructive {
            guard let drawn = row.drawnRow, !titles.contains(drawn.title) else { continue }
            titles.append(drawn.title)
            if titles.count == 3 { break }
        }
        return titles.joined(separator: ", ")
    }

    /// Rows on this page, in the order they are drawn.
    var rows: [SettingsRowID] { SettingsRowID.allCases.filter { $0.page == self } }
    var mainRows: [SettingsRowID] { rows.filter { !$0.inMoreOptions } }
    var moreRows: [SettingsRowID] { rows.filter(\.inMoreOptions) }
    /// Build 52: the rows Settings actually draws on this page.
    var shownMainRows: [SettingsRowID] { mainRows.filter(\.isShown) }
    var shownMoreRows: [SettingsRowID] { moreRows.filter(\.isShown) }

    var footer: String? {
        switch self {
        case .toolbarAndTabs:
            return "Immersive Layout lets pages run edge to edge with controls floating on glass. Turn it off for solid bars. Collapse Toolbar shrinks the bar to the site name as you scroll down; tap it or scroll up to bring it back. Sleep Unused Tabs unloads tabs you have not opened for a while, and they reload when you open them."
        case .privacy:
            return "Close Cookie Banners picks reject or necessary only, and never presses accept. Clear Browsing Data closes all tabs and removes history, cookies, website caches, and saved page zoom levels. Bookmarks and downloads are kept. Reset the App puts every setting back to its default and also deletes your tabs, history, downloads, and website data. Bookmarks are kept."
        case .websites:
            return "Website Location decides whether sites may ask for your real location. Your location goes only to a site you allow, never to Zalla."
        case .about:
            return "Tips through the App Store are optional and do not unlock features. Privacy Policy and Support open zalla.gg in Safari."
        default: return nil
        }
    }
}

extension SettingsRowID {
    /// Build 46: the page this row lives on.
    var page: SettingsPage {
        switch self {
        case .defaultBrowser, .importBookmarks, .exportBookmarks, .iconQuickActions: return .general
        case .appearance, .themeAndAccent, .themePacks, .appIcon: return .appearance
        case .addressBar, .barLayout, .toolbarStyle, .customizeToolbar, .customizeActions, .immersive, .collapseToolbar,
             .statusBarColor, .pageUnderStatusBar, .sleepTabs, .edgeSwipes, .pullToRefresh,
             .pillSwipeTabs, .pageSnapshots, .browsingHaptics, .quietAccent, .titleCrossfade: return .toolbarAndTabs
        case .newTabPage, .addWidgets, .widgets: return .homeAndNewTab
        case .searchEngine, .location: return .search
        case .contentBlocking, .privacyShield, .privacyReport, .httpsOnly, .cookieBanners, .privateTabLock, .autoClear,
             .privacyCover, .burnEffect, .clearData, .resetApp: return .privacy
        case .websiteLocation, .pageZoom, .appBanners, .videoSaver: return .websites
        case .downloads, .networkSpeed, .howTo: return .downloadsAndTools
        case .zallaUnlock, .supportZalla, .privacyPolicy, .support, .acknowledgements, .about: return .about
        }
    }

    /// Build 52: whether Settings draws this row. Set as Default Browser waits for Apple's entitlement, Add Widgets
    /// opened the same screen as Widgets so only Widgets is drawn, and Video Saver is hidden for version 1.
    var isShown: Bool {
        switch self {
        case .defaultBrowser: return FeatureFlags.defaultBrowserEntitled
        case .addWidgets: return false
        // Redesign phase 4: drawn inside the one Layout picker.
        case .addressBar, .toolbarStyle: return false
        case .videoSaver: return FeatureFlags.videoSaverEnabled
        default: return true
        }
    }

    /// The row that is actually drawn for this one, or nil when it is hidden. Auto-clear draws together with
    /// Face ID for private tabs, and Add Widgets is the Widgets row.
    var drawnRow: SettingsRowID? {
        switch self {
        case .autoClear: return .privateTabLock
        case .addWidgets: return .widgets
        case .addressBar, .toolbarStyle: return .barLayout
        default: return isShown ? self : nil
        }
    }

    /// Build 52: where this row lives, for directions in How To and tips, like "Settings, Toolbar and Tabs, More options".
    /// Built from the page and row titles so the directions can't fall out of date when Settings moves things.
    var settingsLocation: String {
        var parts = ["Settings", page.title]
        if inMoreOptions { parts.append(SettingsRowID.moreOptionsTitle) }
        return parts.joined(separator: ", ")
    }

    /// The full path including the row itself, like "Settings, Privacy and Security, Privacy Shield".
    /// Rows drawn inside another row (like Toolbar Style inside Layout) point at the row you can actually see.
    var settingsPath: String {
        let shown = drawnRow ?? self
        return shown.settingsLocation + ", " + shown.title
    }

    /// Extra words people might type when searching Settings.
    var searchKeywords: [String] {
        switch self {
        case .defaultBrowser: return ["default", "open links"]
        case .addWidgets, .widgets: return ["home screen", "widget"]
        case .importBookmarks: return ["safari", "chrome", "favorites"]
        case .exportBookmarks: return ["backup", "favorites", "share"]
        case .contentBlocking: return ["ads", "ad blocker", "trackers", "blocklist"]
        case .privacyShield: return ["fingerprint", "referrer", "dns", "proxy", "tracking links"]
        case .privacyReport: return ["stats", "trackers blocked"]
        case .zallaUnlock: return ["premium", "purchase", "upgrade"]
        case .themePacks: return ["theme", "colors"]
        case .videoSaver: return ["video", "save video"]
        case .searchEngine: return ["google", "duckduckgo", "brave", "kagi", "bing", "custom search"]
        case .location: return ["city", "weather", "local"]
        case .websiteLocation: return ["gps", "permission"]
        case .httpsOnly: return ["secure", "https", "encryption"]
        case .cookieBanners: return ["cookies", "consent", "popups"]
        case .appBanners: return ["open in app", "smart banner"]
        case .iconQuickActions: return ["shortcuts", "press and hold", "3d touch"]
        case .privateTabLock: return ["face id", "passcode", "lock", "private"]
        case .autoClear: return ["clear", "schedule", "history"]
        case .privacyCover: return ["app switcher", "background", "hide"]
        case .burnEffect: return ["fire", "burn", "animation"]
        case .clearData: return ["cookies", "cache", "history", "delete"]
        case .resetApp: return ["defaults", "start over"]
        case .appearance: return ["dark mode", "light mode", "system"]
        case .themeAndAccent: return ["color", "accent", "theme", "gradient"]
        case .appIcon: return ["icon"]
        case .newTabPage: return ["home", "shortcuts", "logo", "welcome", "background", "wallpaper"]
        case .pageZoom: return ["zoom", "text size", "font size"]
        case .addressBar: return ["top", "bottom", "url bar"]
        case .barLayout: return ["safari", "classic", "layout"]
        case .toolbarStyle: return ["compact", "quick action", "style"]
        case .customizeToolbar: return ["buttons", "toolbar", "search bar width"]
        case .customizeActions: return ["menu", "actions"]
        case .immersive: return ["full screen", "edge to edge", "glass"]
        case .statusBarColor: return ["color", "status bar"]
        case .pageUnderStatusBar: return ["status bar", "notch"]
        case .collapseToolbar: return ["scroll", "hide toolbar", "minimize"]
        case .sleepTabs: return ["memory", "battery", "tabs"]
        case .edgeSwipes: return ["gesture", "back", "forward"]
        case .pullToRefresh: return ["reload", "refresh"]
        case .pillSwipeTabs: return ["gesture", "tabs", "swipe"]
        case .pageSnapshots: return ["preview", "picture", "screenshot"]
        case .browsingHaptics: return ["vibration", "feedback"]
        case .quietAccent: return ["gray", "colors", "icons"]
        case .titleCrossfade: return ["animation", "title"]
        case .downloads: return ["files"]
        case .networkSpeed: return ["speed test", "internet", "wifi"]
        case .howTo: return ["help", "tips", "guide"]
        case .supportZalla: return ["tip", "donate"]
        case .privacyPolicy: return ["policy", "data"]
        case .support: return ["help", "contact"]
        case .acknowledgements: return ["licenses", "credits"]
        case .about: return ["version", "what's new"]
        }
    }

    /// True when every word of the query appears in the title, subtitle, page title, or keywords.
    func matchesSearch(_ query: String) -> Bool {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return false }
        let haystack = ([title, subtitle ?? "", page.title] + searchKeywords).joined(separator: " ").lowercased()
        return words.allSatisfy { haystack.contains($0) }
    }

    /// Rows that match a search, grouped by page in main screen order.
    static func searchResults(_ query: String) -> [SettingsSearchResult] {
        SettingsPage.allCases.compactMap { page in
            let hits = page.rows.filter { $0.matchesSearch(query) }
            return hits.isEmpty ? nil : SettingsSearchResult(page: page, rows: hits)
        }
    }
}

/// One page's worth of search hits.
struct SettingsSearchResult: Identifiable, Equatable {
    let page: SettingsPage
    let rows: [SettingsRowID]
    var id: SettingsPage { page }
}
