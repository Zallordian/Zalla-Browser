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
    static let releases: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.0",
            name: "Private by Default",
            highlights: [
                "Free ad and tracker blocker, with an extended tier in Zalla Unlock",
                "Privacy Shield: encrypted DNS, tracking parameters removed from links, fingerprinting protection, referrer trimming and an optional proxy you set up yourself",
                "Brave Search is now the default, with Google, Bing, DuckDuckGo, Startpage, Ecosia, Kagi and custom engines. Press and hold the engine chip to switch",
                "Redesigned Quick Action fan with a separate Menu button",
                "Zalla Unlock: a one-time purchase for Face ID private tabs, background packs, listen to page, tab groups, per-site CSS, scheduled auto-clear and the extended blocker",
                "Tip jar, if you want to support development"
            ],
            improvements: "Search bar width slider. Background picker for the new tab page. Short random sayings on new tabs. Swipe down to dismiss the keyboard. Optional city-only local search, stored on your device with no GPS. Tabs you have not used in a while sleep to save memory. New About page.",
            fixes: "General cleanup and stability work across the app."
        )
    ]

    /// Earlier builds, folded into three beta milestones. Shown under "Before launch".
    static let beta: [ChangelogEntry] = [
        ChangelogEntry(
            version: "Beta 3",
            name: "Make It Yours",
            highlights: [
                "Customizable toolbar",
                "Quick Action toolbar mode, with a search icon and history in the fan",
                "HTTPS-Only mode",
                "Quick Setup during onboarding, with a live preview",
                "Tab restore, so your tabs come back where you left them",
                "App icons that match your custom accent color"
            ],
            improvements: "Translucent toolbar and address bar. Home logo and widgets slider. Popups now work. Camera and microphone permissions for sites that need them. Page title peek.",
            fixes: ""
        ),
        ChangelogEntry(
            version: "Beta 2",
            name: "Everyday Polish",
            highlights: [
                "Settings regrouped so things are easier to find",
                "Share from the Compact toolbar and the Menu",
                "Lock and Not Secure indicator in the address bar",
                "Pages reload automatically if they crash",
                "Privacy and Support links in Settings"
            ],
            improvements: "Better toolbar defaults and tips. Clearer new tab page when empty, and easier shortcuts. Tab spacing and undo after swiping a tab away. Better onboarding defaults. Clearer messages when Reader can't open a page. More download types supported.",
            fixes: "Removed a black box that showed behind the search bar on some screens. Fixed toolbar background fill in several places."
        ),
        ChangelogEntry(
            version: "Beta 1",
            name: "First Look",
            highlights: [
                "Address bar at the top or bottom",
                "Themes and a custom accent color wheel, with hex and gradient options",
                "An app icon for each accent color",
                "Swipe to close tabs, plus Close All",
                "New tab page with quotes or a personal welcome",
                "Network speed test in Settings"
            ],
            improvements: "Search from the Compact toolbar. Tab switcher polish. Reader mode improvements. Better download detection.",
            fixes: "The address bar now focuses reliably when tapped."
        )
    ]
}

/// Contact and legal links shown on the About page.
enum AboutLinks {
    static let privacy = URL(string: "https://zalla.gg/privacy")!
    static let support = URL(string: "https://zalla.gg/support")!
    static let feedbackEmail = "ZallaBrowser@pm.me"
    static var feedbackURL: URL { URL(string: "mailto:\(feedbackEmail)?subject=Zalla%20feedback")! }
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
                detail: "Zalla never uses GPS. You can type a city for local searches, and choose which sites see an approximate spot.",
                status: city.isEmpty ? "Not set" : "City set", isOn: !city.isEmpty
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
