import Foundation

/// Build 41: the Brave style Settings, as plain data. The view draws these rows in this order, and the tests check
/// that every setting Zalla stores still has a home here. Storage keys never change, so nothing is lost.
enum SettingsGroup: String, CaseIterable, Identifiable {
    case top
    case features
    case general
    case privacy
    case display
    case toolbarAndTabs
    case tools
    case support

    var id: String { rawValue }

    /// Section header, or nil for the untitled first card.
    var header: String? {
        switch self {
        case .top: return nil
        case .features: return "Features"
        case .general: return "General"
        case .privacy: return "Privacy"
        case .display: return "Display"
        case .toolbarAndTabs: return "Toolbar and Tabs"
        case .tools: return "Tools"
        case .support: return "Support and About"
        }
    }

    var rows: [SettingsRowID] { SettingsRowID.allCases.filter { $0.group == self } }
}

enum SettingsRowKind: Equatable {
    case toggle
    case link
    case picker
    case action
    case destructive
}

enum SettingsRowID: String, CaseIterable, Identifiable {
    // Top card
    case defaultBrowser, addWidgets, importBookmarks
    // Features
    case contentBlocking, privacyShield, privacyReport, zallaUnlock, themePacks, videoSaver
    // General
    case searchEngine, location, websiteLocation, httpsOnly, cookieBanners, appBanners, iconQuickActions
    // Privacy
    case privateTabLock, autoClear, privacyCover, burnEffect, clearData, resetApp
    // Display
    case appearance, themeAndAccent, appIcon, newTabPage, pageZoom
    // Toolbar and Tabs
    case addressBar, toolbarStyle, customizeToolbar, customizeActions, immersive, statusBarColor
    case pageUnderStatusBar, collapseToolbar, sleepTabs, edgeSwipes, pullToRefresh
    // Tools
    case downloads, networkSpeed, widgets, exportBookmarks, howTo
    // Support and About
    case supportZalla, privacyPolicy, support, acknowledgements, about

    var id: String { rawValue }

    var group: SettingsGroup {
        switch self {
        case .defaultBrowser, .addWidgets, .importBookmarks: return .top
        case .contentBlocking, .privacyShield, .privacyReport, .zallaUnlock, .themePacks, .videoSaver: return .features
        case .searchEngine, .location, .websiteLocation, .httpsOnly, .cookieBanners, .appBanners, .iconQuickActions: return .general
        case .privateTabLock, .autoClear, .privacyCover, .burnEffect, .clearData, .resetApp: return .privacy
        case .appearance, .themeAndAccent, .appIcon, .newTabPage, .pageZoom: return .display
        case .addressBar, .toolbarStyle, .customizeToolbar, .customizeActions, .immersive, .statusBarColor,
             .pageUnderStatusBar, .collapseToolbar, .sleepTabs, .edgeSwipes, .pullToRefresh: return .toolbarAndTabs
        case .downloads, .networkSpeed, .widgets, .exportBookmarks, .howTo: return .tools
        case .supportZalla, .privacyPolicy, .support, .acknowledgements, .about: return .support
        }
    }

    var title: String {
        switch self {
        case .defaultBrowser: return "Set as Default Browser"
        case .addWidgets: return "Add Widgets"
        case .importBookmarks: return "Import Bookmarks"
        case .contentBlocking: return "Content Blocking"
        case .privacyShield: return "Privacy Shield"
        case .privacyReport: return "Privacy Report"
        case .zallaUnlock: return "Zalla Unlock"
        case .themePacks: return "Theme Packs"
        case .videoSaver: return "Video Saver"
        case .searchEngine: return "Search Engine"
        case .location: return "Location"
        case .websiteLocation: return "Website Location"
        case .httpsOnly: return "HTTPS-Only Mode"
        case .cookieBanners: return "Close Cookie Banners"
        case .appBanners: return "App Banners"
        case .iconQuickActions: return "Quick Actions on App Icon"
        case .privateTabLock: return "Face ID for Private Tabs"
        case .autoClear: return "Auto-clear"
        case .privacyCover: return PrivacyCover.title
        case .burnEffect: return "Burn It All Fire Effect"
        case .clearData: return "Clear Browsing Data"
        case .resetApp: return "Reset the App"
        case .appearance: return "Appearance"
        case .themeAndAccent: return "Theme and Accent"
        case .appIcon: return "Change App Icon"
        case .newTabPage: return "New Tab Page"
        case .pageZoom: return "Page Zoom"
        case .addressBar: return "Address Bar"
        case .toolbarStyle: return "Toolbar Style"
        case .customizeToolbar: return "Customize Toolbar"
        case .customizeActions: return "Customize My Actions"
        case .immersive: return "Immersive Layout"
        case .statusBarColor: return "Status Bar Matches the Page"
        case .pageUnderStatusBar: return "Page Under the Status Bar"
        case .collapseToolbar: return "Collapse Toolbar While Scrolling"
        case .sleepTabs: return "Sleep Unused Tabs"
        case .edgeSwipes: return "Swipe From Edges to Go Back"
        case .pullToRefresh: return "Pull Down to Refresh"
        case .downloads: return "Downloads"
        case .networkSpeed: return "Network Speed"
        case .widgets: return "Widgets"
        case .exportBookmarks: return "Export Bookmarks"
        case .howTo: return "How To"
        case .supportZalla: return "Support Zalla"
        case .privacyPolicy: return "Privacy Policy"
        case .support: return "Support"
        case .acknowledgements: return "Acknowledgements"
        case .about: return "About Zalla"
        }
    }

    var symbol: String {
        switch self {
        case .defaultBrowser: return "safari"
        case .addWidgets: return "square.grid.2x2"
        case .importBookmarks: return "square.and.arrow.down"
        case .contentBlocking: return "shield.lefthalf.filled"
        case .privacyShield: return "lock.shield"
        case .privacyReport: return "checklist"
        case .zallaUnlock: return "sparkles"
        case .themePacks: return "paintpalette.fill"
        case .videoSaver: return "film"
        case .searchEngine: return "magnifyingglass"
        case .location: return "location"
        case .websiteLocation: return "location.circle"
        case .httpsOnly: return "lock"
        case .cookieBanners: return "xmark.seal"
        case .appBanners: return "app.badge"
        case .iconQuickActions: return "square.grid.3x3.topleft.filled"
        case .privateTabLock: return "faceid"
        case .autoClear: return "clock.arrow.circlepath"
        case .privacyCover: return "eye.slash"
        case .burnEffect: return "flame"
        case .clearData: return "trash"
        case .resetApp: return "arrow.counterclockwise"
        case .appearance: return "circle.lefthalf.filled"
        case .themeAndAccent: return "paintpalette"
        case .appIcon: return "app"
        case .newTabPage: return "rectangle.on.rectangle"
        case .pageZoom: return "textformat.size"
        case .addressBar: return "rectangle.bottomhalf.inset.filled"
        case .toolbarStyle: return "menubar.rectangle"
        case .customizeToolbar: return "slider.horizontal.3"
        case .customizeActions: return "square.grid.2x2.fill"
        case .immersive: return "rectangle.inset.filled"
        case .statusBarColor: return "paintbrush"
        case .pageUnderStatusBar: return "iphone"
        case .collapseToolbar: return "arrow.down.right.and.arrow.up.left"
        case .sleepTabs: return "moon.zzz"
        case .edgeSwipes: return "hand.draw"
        case .pullToRefresh: return "arrow.down.circle"
        case .downloads: return "arrow.down.circle"
        case .networkSpeed: return "gauge.with.dots.needle.67percent"
        case .widgets: return "square.grid.2x2"
        case .exportBookmarks: return "square.and.arrow.up"
        case .howTo: return "questionmark.bubble"
        case .supportZalla: return "heart"
        case .privacyPolicy: return "doc.text"
        case .support: return "questionmark.circle"
        case .acknowledgements: return "text.book.closed"
        case .about: return "info.circle"
        }
    }

    var kind: SettingsRowKind {
        switch self {
        case .httpsOnly, .cookieBanners, .appBanners, .iconQuickActions, .privateTabLock, .privacyCover, .burnEffect,
             .immersive, .statusBarColor, .pageUnderStatusBar, .collapseToolbar, .sleepTabs, .edgeSwipes, .pullToRefresh,
             .videoSaver:
            return .toggle
        case .searchEngine, .websiteLocation, .appearance, .addressBar, .toolbarStyle:
            return .picker
        case .importBookmarks, .exportBookmarks, .zallaUnlock:
            return .action
        case .clearData, .resetApp:
            return .destructive
        default:
            return .link
        }
    }

    /// Short line under the title, when the row has a fixed one. Live values (like the current engine) are added by the view.
    var subtitle: String? {
        switch self {
        case .defaultBrowser: return "Opens Zalla in the Settings app"
        case .addWidgets: return "Search, favorites, and privacy stats"
        case .importBookmarks: return "From Safari or Chrome"
        case .privacyShield: return "Link cleaning, referrer trimming, fingerprinting"
        case .cookieBanners: return "Never presses accept"
        case .privateTabLock: return "Unlock with Face ID or your passcode"
        case .privacyCover: return "Shows a plain Zalla screen in the background"
        case .resetApp: return "Bookmarks are kept"
        case .pageZoom: return "Saved per site"
        default: return nil
        }
    }

    /// Needs Zalla Unlock to use.
    var needsUnlock: Bool {
        switch self {
        case .privateTabLock, .autoClear: return true
        default: return false
        }
    }

    /// The stored settings this row (or the screen it opens) controls. Keys are the same as before Build 41.
    var storageKeys: [String] {
        switch self {
        case .searchEngine: return ["searchEngine", "customSearchURL"]
        case .contentBlocking: return ["contentBlockingSettings"]
        case .privacyShield: return ["shieldStripTrackingLinks", "shieldTrimReferrer", "shieldFingerprintProtection",
                                     "shieldEncryptedDNS", "shieldDNSProvider", "shieldProxyEnabled", "shieldProxyType",
                                     "shieldProxyHost", "shieldProxyPort"]
        case .privacyReport: return ["privacyReportCounts"]
        case .themePacks: return ["themeRefreshAnimation", "themeTransitionSpeed"]
        case .videoSaver: return ["videoSaverEnabled"]
        case .location: return ["locationCity", "locationCityLatitude", "locationCityLongitude", "locationUseInSearch", "locationSites"]
        case .websiteLocation: return ["websiteLocationMode"]
        case .httpsOnly: return ["httpsOnlyMode"]
        case .cookieBanners: return ["cookieBannerAutoDismiss"]
        case .appBanners: return ["appBanners"]
        case .iconQuickActions: return ["quickActionsEnabled"]
        case .privateTabLock: return ["faceIDPrivateTabs"]
        case .autoClear: return ["autoClearSchedule", "autoClearHistory", "autoClearSiteData"]
        case .privacyCover: return ["privacyCoverInBackground"]
        case .burnEffect: return ["burnAnimation"]
        case .appearance: return ["appearance"]
        case .themeAndAccent: return ["themeID", "useCustomAccent", "customAccentHex", "customAccentGradient", "quickThemeFullLook"]
        case .appIcon: return ["appIconPreference"]
        case .newTabPage: return ["homeShortcuts", "homeShowRecentHistory", "homeWashIntensity", "homeShowLogo",
                                  "homeShowSlider", "homeLogoStyle", "homeWelcomeMode", "homeUserName", "newTabBackground"]
        case .pageZoom: return ["pageZoomByHost"]
        case .addressBar: return ["addressBarPlacement"]
        case .toolbarStyle: return ["toolbarStyle"]
        case .customizeToolbar: return ["toolbarLayout", "searchBarWidth"]
        case .customizeActions: return ["menuTopRow"]
        case .immersive: return ["immersiveLayout"]
        case .statusBarColor: return ["statusBarMatchesPage"]
        case .pageUnderStatusBar: return ["pageUnderStatusBar"]
        case .collapseToolbar: return ["collapseToolbarOnScroll"]
        case .sleepTabs: return ["sleepUnusedTabs"]
        case .edgeSwipes: return ["swipeNavigation"]
        case .pullToRefresh: return ["pullToRefresh"]
        case .widgets, .addWidgets: return ["widgetsShareData", "searchKeyboardReady"]
        default: return []
        }
    }

    /// Every key the new layout covers.
    static var coveredKeys: Set<String> { Set(allCases.flatMap(\.storageKeys)) }
}
