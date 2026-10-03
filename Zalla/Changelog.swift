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
            version: "Build 28",
            name: "Smooth Moves",
            highlights: [
                "Everyday motion now feels closer to Safari: springy, quick, and easy to interrupt. The address bar opens and closes with a spring, the Reload and Stop icon swaps with a little morph, the loading bar eases along, pages fade in as they commit, and the new tab page fades in instead of snapping",
                "Tabs move with a spring. Cards slide into place when one closes, a card follows your finger when you swipe it away (a quick flick works too, and a short swipe springs back), and the Tab closed bar slides up from the bottom",
                "In Settings, the underline under the category tabs slides to the next tab and the page glides across, the custom accent controls ease open, and a tapped theme swatch or app icon gives a little pop"
            ],
            improvements: "Every new animation follows Reduce Motion (no motion, or a short fade) and comes from one shared set of timings. Toasts, the Quick Action fan, and the edge swipe arrow also ease in and out.",
            fixes: ""
        ),
        ChangelogEntry(
            version: "Build 27",
            name: "Seamless Top",
            highlights: [
                "The strip behind the clock and battery now matches what the page actually shows at its top edge, so a site like Reddit (black header) or YouTube in dark mode looks like one continuous page instead of a border. Pages scroll like a normal website, and the strip follows the page color as headers slide away or stick, without a flash while pages load"
            ],
            improvements: "The strip color eases over in a quick blink, tiny color shifts are ignored, and the clock and battery text no longer flip back and forth on mid gray pages. Pulling the page down past its top now shows the strip color instead of a gap.",
            fixes: "Fixed the top of the page looking off while scrolling on some sites, and the strip flashing white while a page was still loading."
        ),
        ChangelogEntry(
            version: "Build 26",
            name: "Neon, Frost, Blossom",
            highlights: [
                "Three more theme packs in Zalla Unlock: Neon City (magenta and cyan glow, with a flickering neon wipe and glow streaks), Arctic (ice blue, with frost that spreads in from the corners and snow sparkle), and Cherry Blossom (soft pinks, with a swirl of petals that sweeps across). Each has an accent, an app icon, and three new tab backgrounds, and they show up in Quick theme and Explore theme packs",
                "Tabs and Share traded places. The Compact bar now has Tabs next to the menu button, instead of Share, and the address pill no longer repeats the Tabs icon. The top row of the Menu now has Share instead of Tabs. If you never changed these, you get the new setup on its own. If you did, nothing moves, and Settings, Appearance still lets you put either one wherever you like"
            ],
            improvements: "The theme swatches in Settings, Appearance wrap onto three tidy rows. The new themes follow the same On and Off and Speed switches, and Reduce Motion plays the quick fade.",
            fixes: ""
        ),
        ChangelogEntry(
            version: "Build 25",
            name: "One Tap Theme",
            highlights: [
                "Tapping a theme in Settings, Appearance now changes the whole theme, not just the color. Pick Volcano, Deep Ocean, Retro Arcade, Jungle, or Space and you get its accent, app icon, new tab background, and refresh transition in one go, with the transition playing right away. Locked themes show a lock and open Zalla Unlock instead of changing anything",
                "The row below is now Explore theme packs, for looking around the premium themes. The section is called Theme and accent, and the old Signature row is Quick theme"
            ],
            improvements: "Settings, Appearance, Themes apply the full look turns it off, so a tap only sets the accent like before. Free accents, Zalla Red as the default, and the custom accent still work the same, and picking a theme turns the custom accent off.",
            fixes: ""
        ),
        ChangelogEntry(
            version: "Build 24",
            name: "Header Room",
            highlights: [
                "Fixed: a site's own header at the top of the page, like the YouTube logo and search icon, was hidden under the colored status bar strip. The page now starts right below the clock, so headers show up on a normal load"
            ],
            improvements: "Nothing changes with Immersive layout off, and the new tab page keeps its full bleed wallpaper.",
            fixes: "YouTube's top header no longer disappears on a normal load."
        ),
        ChangelogEntry(
            version: "Build 23",
            name: "Float On",
            highlights: [
                "The bottom bar now floats for real, like Safari on iOS 26. No frosted box behind it: the Back button, the address, and the menu button are each their own little glass shape sitting right on the page, with the page showing through the gaps. Classic, Compact, and Quick Action all float the same way, everything is about 12 percent smaller, and Settings, Appearance, Immersive layout still brings back the solid bars",
                "The page now starts below the clock instead of running under it, and the status bar area takes on the page's own color, so YouTube keeps its logo and the top looks seamless. Light pages get dark text and dark pages get light text. Settings, Appearance, Status bar matches the page turns it off",
                "App banners: when a site says it has an app (the same hint Safari reads), a slim banner under the status bar offers Open in the app. It only opens an app you already have, never goes to the App Store, and never calls Apple. Dismiss it and it stays away for that site until you quit Zalla. Settings, Browsing, App banners turns it off",
                "Three new theme packs in Zalla Unlock: Volcano (black and ember red, with a lava wipe and flying sparks), Deep Ocean (teal and aqua, with a wave that rolls across and pulls back, bubbles, and light rays), and Retro Arcade (pink, blue, and yellow pixel stars, with a CRT pixel dissolve). Each has an accent, an app icon, and new tab backgrounds"
            ],
            improvements: "The new themes play on refresh and when applied, follow the same On and Off and Speed switches in Settings, Theme packs, and get the quick fade when Reduce Motion is on. The new tab page keeps its full bleed wallpaper.",
            fixes: "The status bar clock and the YouTube logo are no longer hidden by the page."
        ),
        ChangelogEntry(
            version: "Build 22",
            name: "Edge to Edge",
            highlights: [
                "Pages now run edge to edge, under the status bar and down to the bottom of the screen, like Safari on iOS 26. The bar floats over the page as a frosted glass capsule just above the home indicator, and the page still scrolls clear of it. It works with Classic, Compact, Quick Action, and a bar on top. Settings, Appearance, Immersive layout turns it off for the solid bars",
                "The top row of the Menu is yours now: Back, Forward, Reload, Tabs, and a new Settings gear by default. Settings, Appearance, Customize Menu Row lets you pick and reorder, and adds Share, Bookmark, Find on page, New tab, Burn It All, Downloads, and Home",
                "Settings tabs are bigger, the one you pick slides to the middle, there is a small tap when it changes, and the edges fade when more tabs are hiding off screen"
            ],
            improvements: "The bar sits closer to the bottom edge, with a smaller gap under it, even with Immersive layout off. The Burn It All flames have softer curved edges, a glow in the bright core, and sparks and ash among the embers, with the same timing as before.",
            fixes: ""
        ),
        ChangelogEntry(
            version: "Build 21",
            name: "Settings, Sorted",
            highlights: [
                "Settings is now a row of tabs across the top: Appearance, Privacy, Browsing, Tools, Premium, and About. Tap a tab or swipe sideways. Zalla remembers the one you were on",
                "The long explanation under Privacy now folds away under What these do. Face ID for private tabs and Auto-clear moved to the new Premium tab, next to a Zalla Unlock row and Theme packs"
            ],
            improvements: "Nothing was removed or renamed, and every switch keeps its setting. The tab names read aloud with the selected one announced, the strip scrolls at large text sizes, and Reduce Motion skips the sliding.",
            fixes: ""
        ),
        ChangelogEntry(
            version: "Build 20",
            name: "One Burn Is Enough",
            highlights: [
                "Burn It All no longer lights a second, smaller fire at the bottom of the screen while it says Clearing browsing data. The flames burn out once, then it is just black and the label"
            ],
            improvements: "",
            fixes: "The Burn It All effect keeps its own clock, so it can no longer start over when the tabs close behind it."
        ),
        ChangelogEntry(
            version: "Build 19",
            name: "Pull Down, Burn Up",
            highlights: [
                "Burn It All has a new look: flames in yellow, orange, and red rise over your page, break apart into embers, and fade to black, then a plain Clearing browsing data label shows until Zalla closes. Settings, Privacy has a switch if you prefer a quiet fade",
                "Pull down at the top of any page to reload it, with a spinner that stops when the page is done. It is on by default and has a switch in Settings, Browsing",
                "The new tab page is now the first page of every tab's history. Swipe back from your first site and you land on it, and swipe forward to return. The Back and Forward buttons and the history peek know about it too"
            ],
            improvements: "Jungle and Space got a glow-up: more organic leaves in layers that sway and cast soft shadows, and a sleeker rocket with a long tapering flame, smoke puffs, and a smoother climb. Same On and Off and Speed switches, and Reduce Motion still gets a quick fade.",
            fixes: "Going back from the first page no longer leaves you with nowhere to go."
        ),
        ChangelogEntry(
            version: "Build 18",
            name: "Swipe, Sweep, Burn",
            highlights: [
                "Swiping in from the screen edge now goes back and forward. It was supposed to before. It is now Zalla's own swipe, with a little arrow that follows your finger",
                "Jungle and Space got proper full-screen transitions: a leafy curtain and a rocket. Switch them off or set the speed in Settings, Theme packs",
                "Burn It All now lights the browser from the edges and burns it toward the middle before closing",
                "The Zalla logo on your new tab turns white or black when red would get lost. Logo style in Settings, Home lets you pick"
            ],
            improvements: "The saying, shortcut names, and the pencil on the new tab page now pick light or dark to read on your wallpaper. Reduce Motion gets a quick fade instead of the big effects. Burn It All finishes its wipe even if you close Zalla while the flames are going.",
            fixes: "Edge swipe now works on every tab, including new ones."
        ),
        ChangelogEntry(
            version: "Build 17",
            name: "Menus that line up",
            highlights: [
                "Burn It All now asks in the middle of the screen, not in a little popover at the top pointing at the wrong button",
                "Close all tabs, Clear browsing data, Reset the App, and the other are-you-sure questions ask the same way, each with a Cancel",
                "Bookmark page now tells you it worked"
            ],
            improvements: "Find on page opens its bar and keyboard once the Menu has closed. Page Zoom has room for its footnote. Downloads in Settings no longer has a Done button that only goes back. Resetting the new tab page asks first and updates the page right away. Editing a shortcut checks its address the way Add Shortcut does.",
            fixes: "The search engine menu in setup no longer repeats its own label."
        ),
        ChangelogEntry(
            version: "Build 16",
            name: "Where You At",
            highlights: [
                "Websites can now ask for your location, for weather, nearby coffee, and the occasional map. Zalla asks you first, every time or once per site, and the default is still Ask",
                "Prefer to stay unfindable? Settings, Privacy, Website location, Never. Sites get a polite no and you get no prompts",
                "Your location goes only to the site you allow. Not to Zalla, and not anywhere else. Private tabs ask every time and remember nothing",
                "Changed your mind? Settings, Privacy, Location lists every site you answered. Swipe one away and it has to ask again"
            ],
            improvements: "Burn It All and Reset the App now forget which sites you said yes or no to. Safety at a glance gets a Website location row. The Location page now says plainly that typing a city never uses GPS.",
            fixes: "The Location page no longer claims Zalla never asks iOS for your location, because now it can, if you say so."
        ),
        ChangelogEntry(
            version: "Build 15",
            name: "Fewer Loose Ends",
            highlights: [
                "The Flame is now Burn It All, and its icon wears your accent color. Find it in Tabs, the Menu, or add it to your Quick Action buttons",
                "Listen to Page keeps talking when you leave the app or lock your phone",
                "Zalla can now reach devices on your local network, like a printer page or a home server, when you open their address"
            ],
            improvements: "Bookmark import runs in the background and reads more kinds of special characters. Local and private network addresses, including Tailscale ones, always open as typed. Timeouts now show the normal error page instead of the encryption warning. The HTTPS upgrade count in your privacy report only counts pages that really loaded securely.",
            fixes: "If Zalla Unlock ever lapses, locked accents and icons return to the default straight away. A hiccup while checking a purchase no longer takes Unlock away. Locked private tabs are properly hidden from VoiceOver. Cookie banner closing no longer touches ordinary pop-ups. Link cleaning cannot loop. Reset App now resets the search bar width, and Burn It All also forgets which sites you asked for the desktop version of."
        ),
        ChangelogEntry(
            version: "Build 14",
            name: "Built Around You",
            highlights: [
                "The Flame, since renamed Burn It All: one confirmed tap erases your tabs, history, cookies, and site data, then closes Zalla. Free",
                "HTTPS-Only Mode is now on by default, with a clear warning page and a per-site Continue anyway",
                "A tidier new tab page: no preloaded shortcuts, a plus tile, and an Add Shortcut list of popular sites, your bookmarks, or any address. Press and hold a link on any page to add it",
                "Space and Jungle theme packs in Zalla Unlock: accents, icons, backgrounds, and an optional refresh animation that respects Reduce Motion",
                "Swipe in from the screen edge to go back and forward, with a switch in Settings",
                "Privacy report for the page you are on and for everything Zalla has done for you, plus optional cookie banner closing that never presses accept",
                "Friendly pages for no internet, slow sites, and bad certificates",
                "A How to section in Settings for Quick Action and the other gestures"
            ],
            improvements: "The toolbar blur now stays live over scrolling pages. Swipe down on a page to put the keyboard away, everywhere. Request Desktop Site is remembered per site. Downloads open in a proper preview. Bookmark import understands more Safari and Chrome exports. Zalla can open links from other apps.",
            fixes: "Fixed the toolbar background looking frozen instead of translucent."
        ),
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
                detail: "Erases tabs, history, cookies, and site data in one confirmed tap, then closes Zalla. Free.",
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
