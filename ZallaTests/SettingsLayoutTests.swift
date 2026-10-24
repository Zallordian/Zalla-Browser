import XCTest
@testable import Zalla

/// Build 41: the Brave style Settings must still reach every setting the old tabbed layout had.
final class SettingsLayoutTests: XCTestCase {
    /// Every key the old Settings tabs (and the screens they pushed) let you change. Haptic tap on Settings tabs
    /// and the remembered tab are gone with the tab strip, by design.
    private let oldSettingsKeys: [String] = [
        "appearance", "themeID", "useCustomAccent", "customAccentHex", "customAccentGradient", "appIconPreference",
        "toolbarStyle", "addressBarPlacement", "immersiveLayout", "statusBarMatchesPage", "pageUnderStatusBar",
        "collapseToolbarOnScroll", "toolbarLayout", "searchBarWidth", "menuTopRow", "quickThemeFullLook",
        "newTabBackground", "themeRefreshAnimation", "themeTransitionSpeed",
        "homeShortcuts", "homeShowRecentHistory", "homeWashIntensity", "homeShowLogo", "homeShowSlider",
        "homeLogoStyle", "homeWelcomeMode", "homeUserName",
        "contentBlockingSettings", "shieldStripTrackingLinks", "shieldTrimReferrer", "shieldFingerprintProtection",
        "shieldEncryptedDNS", "shieldDNSProvider", "shieldProxyEnabled", "shieldProxyType", "shieldProxyHost",
        "shieldProxyPort", "privacyReportCounts", "cookieBannerAutoDismiss", "locationCity", "locationCityLatitude",
        "locationCityLongitude", "locationUseInSearch", "locationSites", "websiteLocationMode", "httpsOnlyMode",
        "burnAnimation", "privacyCoverInBackground", "searchEngine", "customSearchURL", "sleepUnusedTabs",
        "swipeNavigation", "pullToRefresh", "appBanners", "quickActionsEnabled", "widgetsShareData",
        "searchKeyboardReady", "faceIDPrivateTabs", "autoClearSchedule", "autoClearHistory", "autoClearSiteData",
        "videoSaverEnabled", "pageZoomByHost"
    ]

    func testEveryOldKeyHasARow() {
        let covered = SettingsRowID.coveredKeys
        let missing = oldSettingsKeys.filter { !covered.contains($0) }
        XCTAssertEqual(missing, [], "Settings keys with no row in the new layout: \(missing)")
    }

    func testKeyLiteralsMatchTheirConstants() {
        let constants: [String] = [
            ToolbarStyle.storageKey, AddressBarPlacement.storageKey, ImmersiveLayout.storageKey, PageColor.storageKey,
            ScrollChrome.underStatusBarKey, ScrollChrome.collapseKey, HTTPSOnly.storageKey, BurnEffectPlan.animationKey,
            TabSleep.storageKey, SwipeNavigation.storageKey, PullToRefresh.storageKey, QuickAction.storageKey,
            VideoSaver.storageKey, CookieBannerDismiss.storageKey, PrivacyCover.storageKey, AppBanner.storageKey,
            WebsiteLocation.modeKey, QuickTheme.storageKey, NewTabBackground.storageKey, ThemePacks.transitionsKey,
            ThemeTransitionSpeed.storageKey, MenuTopRow.storageKey, PageZoom.storageKey, PrivacyReport.storageKey,
            SearchEngine.storageKey, SearchEngine.customTemplateKey
        ]
        let covered = SettingsRowID.coveredKeys
        for key in constants {
            XCTAssertTrue(covered.contains(key), "\(key) has no row")
        }
    }

    func testDroppedKeysAreNotShown() {
        XCTAssertFalse(SettingsRowID.coveredKeys.contains(SettingsTabHaptics.storageKey))
        XCTAssertFalse(SettingsRowID.coveredKeys.contains(SettingsCategory.storageKey))
    }

    func testEveryGroupHasRowsAndOnlyTopIsUntitled() {
        for group in SettingsGroup.allCases {
            XCTAssertFalse(group.rows.isEmpty, "\(group) is empty")
            XCTAssertEqual(group.header == nil, group == .top)
        }
    }

    func testRowIDsAreUniqueAndTitled() {
        XCTAssertEqual(Set(SettingsRowID.allCases.map(\.title)).count, SettingsRowID.allCases.count)
        for row in SettingsRowID.allCases {
            XCTAssertFalse(row.title.isEmpty)
            XCTAssertFalse(row.symbol.isEmpty)
        }
    }
}

/// Build 41 copy rules: no em or en dashes, and no VPN wording outside the lines that say Zalla is not a VPN.
final class Build41CopyTests: XCTestCase {
    private var menuAndSettingsCopy: [String] {
        var lines: [String] = []
        for row in SettingsRowID.allCases {
            lines.append(row.title)
            if let subtitle = row.subtitle { lines.append(subtitle) }
        }
        lines += SettingsGroup.allCases.compactMap(\.header)
        for item in MenuTopRow.allCases {
            lines.append(item.title)
            lines.append(item.shortTitle)
        }
        lines.append(BurnCopy.menuFooter)
        return lines
    }

    func testNoDashes() {
        for line in menuAndSettingsCopy {
            XCTAssertFalse(line.contains("\u{2014}"), "Em dash in: \(line)")
            XCTAssertFalse(line.contains("\u{2013}"), "En dash in: \(line)")
        }
    }

    func testNoVPNWordingExceptNotAVPN() {
        for line in menuAndSettingsCopy where line.localizedCaseInsensitiveContains("vpn") {
            let lower = line.lowercased()
            XCTAssertTrue(lower.contains("not a vpn") || lower.contains("not provide a vpn") || lower.contains("is not a vpn"),
                          "VPN wording in: \(line)")
        }
    }
}
