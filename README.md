# Zalla

**Built around you.** A free, privacy-conscious iPhone browser, with a one-time Zalla Unlock of about $2 (the price shown in the App Store is the one that applies).

## Current milestone

Native SwiftUI + WKWebView foundation targeting iPhone on iOS 17+. This is early source code, not an App Store-ready or device-verified build. No Swift compiler, iOS simulator, or Xcode is available in the originating Windows workspace.

Implemented in source:
- Address/search input, back/forward gestures and buttons, reload/stop, progress and error messages.
- Multiple regular tabs and private tabs with separate nonpersistent website stores.
- Local bookmarks and history (most recent 500 unique URLs); private visits excluded.
- Native page sharing and confirmed telephone, SMS, and email handoffs.
- Red-accent start page, local favorites, system/light/dark appearance, three search engines.
- Clear history and website data, closing tabs before deletion; bookmarks retained.
- App-switcher privacy cover; device-protected library file excluded from OS backup.

## Build 18

- Edge swipe fixed. Cause: the old setting relied on WebKit's `allowsBackForwardNavigationGestures`, which could not be confirmed on device in this layout (the web view sits full-bleed under a SwiftUI ZStack with the chrome and gesture overlays above it, and the system edge pan is not guaranteed to reach it there). Zalla now installs its own `UIScreenEdgePanGestureRecognizer` pair on every web view (left edge back, right edge forward), with a small arrow cue, a distance or flick threshold, and a haptic. WebKit's own gesture is switched off so the two never both fire. It is installed when a tab is created and again whenever a tab is shown, and the Settings, Browsing toggle (on by default) applies live to every tab.
- Logo contrast: white and black variants of the Zalla mark (`ZallaMarkWhite`, `ZallaMarkBlack`, made from the red logo's alpha channel). Settings, Home, Logo style: Auto (default), Zalla red, White, Black. Auto picks by the background's contrast and its distance from Zalla red. The saying, shortcut names, View library, and the pencil follow the same luminance rule on wallpapers. The rules live in `LogoStyle.swift` and are covered by Linux tests.
- Theme transitions replace the emoji animations. Jungle is a three-layer leaf curtain that slides in from both sides and back out. Space is a rocket with a flame trail and an exhaust glow that fills the screen and lifts away upward. About a second at Normal. Settings, Theme packs, Customization: Theme transitions On or Off and Speed Slow, Normal, or Fast. They play on a user-initiated reload and when a theme pack is applied. Reduce Motion plays a quick fade. Zalla Unlock gating is unchanged. The On/Off switch keeps its Build 14 storage key.
- Burn It All plays a fire effect (flames from all four edges toward the middle, about 1.2 seconds, Reduce Motion fades), then runs the existing wipe and `exit(0)`. The wipe starts before the animation and runs twice, and a launch flag makes the next start finish the wipe if the app was closed halfway, so nothing restores.
- Build number 18, a Build 18 changelog entry, How to pages for transitions and the updated edge swipe, logo, and Burn It All.

## Build 17

- Burn It All and the other are-you-sure questions (close all tabs, clear browsing data, reset the app, clear downloads, reset the privacy report, open another app, matching app icon) are now centered alerts with a Cancel. On iPhone a confirmation dialog can render as a popover pinned to a distant view, which is what put Burn It All at the top of the Menu sheet with its arrow on the wrong row.
- Menu and layout fixes found in an audit: Find on page opens after the Menu closes, Bookmark page shows a toast, the Page Zoom sheet is taller, Downloads in Settings has no Done, the setup search engine menu has no doubled label, resetting the new tab page asks first and refreshes the page, and the shortcut editor validates addresses like Add Shortcut does.
- Dead code removed: the unused Home personalization sheet case, a no-op long press on the Compact tabs button, and an unused refresh animation helper.

## Build 16

- Website location: sites can now ask for your real location (weather, nearby businesses, maps). Settings, Privacy, Website location is Ask by default, or Never to block every request without a prompt. Zalla asks Allow or Don't Allow per site and remembers the answer; Settings, Privacy, Location lists the answers so you can forget one. Private tabs ask every time and remember nothing.
- Your location goes only to the site you allow, through WebKit. It never goes to Zalla, and Zalla keeps no copy. Typing a city for local search still never uses GPS.
- Burn It All and Reset the App forget remembered per-site location answers. Reset also puts Website location back to Ask.
- Uses `NSLocationWhenInUseUsageDescription`. The in-app Allow or Don't Allow prompt, and remembered answers, use WebKit's geolocation delegate, which is public API from iOS 27. On iOS 17 to 26, WebKit shows its own prompt, and Never and Don't Allow are enforced by a script in the page.
- A How to page, a Safety at a glance row, and a Build 16 changelog entry.

## Build 15

- The Flame is now Burn It All (free). It sits in Tabs, the Menu, and as an optional Quick Action button, no longer in the new tab edit menu, and its icon follows the accent color.
- Listen to Page keeps playing in the background (audio background mode). Local network access is declared for LAN addresses.
- If Zalla Unlock lapses, locked accents and app icons fall back to the default right away. A purchase check that cannot be verified never removes a cached Unlock.
- HTTPS-Only: local ranges now include 100.64.0.0/10, `::` and mapped IPv4. Timeouts show the normal error page. Upgrades are counted only when the secure page loads.
- Cookie banner closing ignores generic dialogs. Link cleaning is capped per navigation. Bookmark import parses in the background and decodes numeric entities.
- The About "Our story" section is hidden until there is real copy (one flag, `AboutLinks.showsStory`).
- Privacy manifest added (no tracking, no collected data, UserDefaults reason CA92.1).

## Build 14

- Burn It All (free, called the Flame in Build 14): confirm, then erase tabs, history, cookies, and site data, and close the app.
- HTTPS-Only Mode is on by default, with a warning page and a per-site Continue anyway. Local and private network addresses are exempt.
- New tab page: no preloaded shortcuts, a plus tile, an edit menu, and an Add Shortcut sheet (bundled popular sites, bookmarks, or a typed address). Press and hold a link on a page to Add to Dashboard.
- Theme packs in Zalla Unlock: Space and Jungle, each with an accent, an app icon, new tab backgrounds, and an optional refresh animation that respects Reduce Motion (replaced by full-screen transitions in Build 18).
- Swipe from the screen edge to go back and forward (Settings toggle, on by default). Swipe down on a page or in any list to put the keyboard away.
- The translucent toolbar material is now a plain live blur, and the web view is see-through, so pages scroll visibly beneath the bars.
- Privacy report (free): per site and overall counts of things Zalla did itself (links cleaned, HTTPS upgrades, cookie banners closed) plus third-party sites the page contacted. There is deliberately no "trackers blocked" total, because WebKit content rules do not report one.
- Cookie banner closing: presses reject or necessary only on known banners, never accept. Off in private tabs. Settings toggle in Privacy.
- Per-site Request Desktop Site, kept per host. Downloads open in Quick Look. Bookmark import reads more Safari, Chrome, and Firefox HTML exports.
- Friendly pages for no internet, timeouts, unreachable sites, and bad certificates. A How to section in Settings.
- Links from other apps: `zalla://open?url=<address>` opens in Zalla. Becoming the system default browser needs Apple's browser entitlement, which is not requested yet, so http and https links from other apps are not routed to Zalla.
- Passwords: Zalla has no vault. Sign-in uses Apple AutoFill and passkeys through WebKit and the system.

No external SDKs, analytics, account service, or Zalla backend. Optional tips and Zalla Unlock use StoreKit in-app purchases. Content blocking uses bundled rule lists converted from EasyList, EasyPrivacy, and Fanboy lists (see [tools/blocklists](tools/blocklists/README.md)). Open normal tabs are restored after termination. Each private tab is isolated, so logins are not shared across private tabs. Explicitly bookmarking or sharing a private page is a user-directed export.

## Build on a Mac

1. Install Xcode with the iOS SDK and XcodeGen (https://github.com/yonaskolb/XcodeGen).
2. In this folder run `xcodegen generate` and open `Zalla.xcodeproj`.
3. Select the Zalla scheme and an installed iPhone simulator; build and run.
4. Run the ZallaTests target with Product → Test.
5. For a physical iPhone, choose your Apple development team in Signing & Capabilities and replace the placeholder bundle identifier with one you control.

The project specification generates Info.plist. The web-content-only App Transport Security exception permits user-requested HTTP websites; native app network requests retain platform defaults. TLS failures use WebKit's default handling. The [icon kit](docs/branding/icons/README.md) includes a configured app icon catalog, appearance variants and development exports; Mac/device validation and native Icon Composer adoption remain release work. Default-browser entitlements, signing, and App Store metadata are intentionally still release work.

See [product direction](docs/PRODUCT.md) and [device validation](docs/VALIDATION.md). The original project handoff remains unchanged.
