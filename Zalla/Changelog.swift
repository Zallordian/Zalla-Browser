import Foundation

/// One release in the About page's "What's new". Bundled with the app so it works offline.
struct ChangelogEntry: Identifiable, Equatable {
    var id: String { version }
    let version: String
    let name: String
    let highlights: [String]
    let improvements: String
    let fixes: String
}

enum Changelog {
    /// Newest first. Add future releases (1.1, 1.2, and so on) at the top of `releases`.
    /// The TestFlight build history lives in docs/CHANGELOG_HISTORY.md.
    static let releases: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.0",
            name: "Private by Default",
            highlights: [
                "Tracker and ad blocking that is on from the start, free, with a switch for every site",
                "Burn It All: one tap erases your tabs, history, cookies, and site data, then opens a fresh tab",
                "Privacy Shield cleans tracking tags from links, trims referrers, and can add fingerprinting protection or use a proxy you set up. It is not a VPN",
                "Make it yours with themes, accent colors, app icons, toolbar layouts, and a home page you arrange",
                "Private tabs that keep nothing after you close them"
            ],
            improvements: "Reader mode, widgets, Listen to page, HTTPS-Only Mode, cookie banner closing that never presses accept, and a privacy report that stays on your iPhone. Zalla Unlock adds extra blocking, theme packs, Face ID for private tabs, tab groups, and more, for a one-time purchase.",
            fixes: "Thanks to everyone who tested Zalla on TestFlight. Your notes shaped this release."
        )
    ]

    /// Earlier builds. Empty for the public release; see docs/CHANGELOG_HISTORY.md.
    static let beta: [ChangelogEntry] = []
}

/// Contact and legal links shown on the About page.
enum AboutLinks {
    static let privacy = URL(string: "https://zalla.gg/privacy")!
    static let support = URL(string: "https://zalla.gg/support")!
    static let feedbackEmail = "ZallaBrowser@pm.me"
    static var feedbackURL: URL { URL(string: "mailto:\(feedbackEmail)?subject=Zalla%20feedback")! }
    /// Flip to true once the real story copy replaces the placeholder below.
    static let showsStory = false
    static let storyPlaceholder = "The story behind Zalla is coming soon."
}

/// One feature on the Safety at a glance list.
struct SafetyItem: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let detail: String
    /// Live status shown at the right, such as "On" or "Off".
    let status: String
    let isOn: Bool
}

enum SafetyOverview {
    /// Builds the list from the current settings. Pure so it can be tested with a scratch UserDefaults.
    static func items(unlocked: Bool, defaults: UserDefaults = .standard) -> [SafetyItem] {
        let blocking = blockingIsOn(defaults)
        let httpsOnly = HTTPSOnly.enabled(in: defaults)
        let proxy = ProxySettings.stored(in: defaults)
        let faceID = PrivateTabLock.isRequired(unlocked: unlocked, defaults: defaults)
        let schedule = unlocked ? AutoClear.schedule(defaults) : .off
        let city = LocationSettings.city(defaults)
        let websiteLocation = WebsiteLocation.mode(defaults)
        return [
            SafetyItem(
                title: "Ad and tracker blocking",
                detail: "Stops trackers and common ads on this device. Extra lists come with Zalla Unlock.",
                status: blocking ? "On" : "Off", isOn: blocking
            ),
            SafetyItem(
                title: "HTTPS-Only Mode",
                detail: "Opens sites over secure connections and asks before loading one that does not support them.",
                status: httpsOnly ? "On" : "Off", isOn: httpsOnly
            ),
            SafetyItem(
                title: "Burn It All",
                detail: BurnCopy.safetyDetail,
                status: "Ready", isOn: true
            ),
            SafetyItem(
                title: "Cookie banners",
                detail: "Picks reject or necessary only on consent banners it recognizes. It never presses accept.",
                status: CookieBannerDismiss.enabled(in: defaults) ? "On" : "Off", isOn: CookieBannerDismiss.enabled(in: defaults)
            ),
            SafetyItem(
                title: "Clean tracking from links",
                detail: "Removes tags such as utm_source and fbclid from page addresses.",
                status: PrivacyShield.stripLinks(defaults) ? "On" : "Off", isOn: PrivacyShield.stripLinks(defaults)
            ),
            SafetyItem(
                title: "Trim referrer",
                detail: "Tells the next site only where you came from, not the exact page.",
                status: PrivacyShield.trimReferrer(defaults) ? "On" : "Off", isOn: PrivacyShield.trimReferrer(defaults)
            ),
            SafetyItem(
                title: "Fingerprinting protection",
                detail: "Makes your device a little harder to tell apart. It does not make you anonymous.",
                status: PrivacyShield.fingerprintProtection(defaults) ? "On" : "Off", isOn: PrivacyShield.fingerprintProtection(defaults)
            ),
            SafetyItem(
                title: "Encrypted DNS",
                detail: "Encrypts name lookups for Zalla's own requests, such as image export and the speed test. Web pages use your iPhone's DNS settings.",
                status: PrivacyShield.encryptedDNS(defaults) ? "On" : "Off", isOn: PrivacyShield.encryptedDNS(defaults)
            ),
            SafetyItem(
                title: "Your own proxy",
                detail: "Sends page traffic through a proxy you set up. The proxy can see the sites you visit.",
                status: proxy == nil ? "Off" : "On", isOn: proxy != nil
            ),
            SafetyItem(
                title: "Private tabs",
                detail: "Keep no history, cookies, or site data after the tab closes. They are never saved for the next launch.",
                status: "Always available", isOn: true
            ),
            SafetyItem(
                title: "Face ID for private tabs",
                detail: "Asks for Face ID or your passcode before private tabs open. Part of Zalla Unlock.",
                status: faceID ? "On" : (unlocked ? "Off" : "Locked"), isOn: faceID
            ),
            SafetyItem(
                title: "Auto-clear",
                detail: "Clears history and website data on a schedule you pick. Part of Zalla Unlock.",
                status: unlocked ? (schedule == .off ? "Off" : schedule.rawValue) : "Locked", isOn: schedule != .off
            ),
            SafetyItem(
                title: "Location",
                detail: "Typing a city never uses GPS. You can use it for local searches, and choose which sites see an approximate spot.",
                status: city.isEmpty ? "Not set" : "City set", isOn: !city.isEmpty
            ),
            SafetyItem(
                title: "Website location",
                detail: "Sites can ask where you are, and nothing is shared unless you say yes. Your location goes only to the site you allow, never to Zalla. Private tabs ask every time.",
                status: websiteLocation.title, isOn: true
            ),
            SafetyItem(
                title: "Your data stays here",
                detail: "Bookmarks, history, and settings are saved on this device. No account, no analytics, no advertising SDKs.",
                status: "On this device", isOn: true
            )
        ]
    }

    private static func blockingIsOn(_ defaults: UserDefaults) -> Bool {
        guard let data = defaults.data(forKey: ContentBlockingSettings.storageKey),
              let settings = try? JSONDecoder().decode(ContentBlockingSettings.self, from: data) else { return true }
        return settings.isEnabled
    }
}
