# Product direction

## Mission
Make a premium, useful gateway to the internet available without selling user data. Zalla operates without its own backend. Internet access still depends on the user's network; browsing contacts websites and search providers, and purchases will contact Apple.

## Working decisions
- Zalla / “Built around you.” / crimson brand, as recorded in the original handoff.
- iPhone first, native SwiftUI and system WebKit. iOS 17 is a provisional minimum.
- No account, analytics SDK, advertising SDK, proprietary credential vault, or cloud sync.
- Core browsing and meaningful privacy controls remain free.
- Zalla Unlock: a lifetime upgrade of about $2 (US $1.99 price point), using a StoreKit non-consumable. Final localized price comes from App Store Connect and StoreKit, not a hardcoded price. No subscription. Unlock covers stronger blocking, Face ID for private tabs, tab groups, listen to page, per-site CSS, scheduled auto-clear, background packs, and the Space, Jungle, Volcano, Deep Ocean, Retro Arcade, Neon City, Arctic, and Cherry Blossom theme packs, including their full-screen transitions (On or Off, Slow, Normal, or Fast). Core blocking, Burn It All, HTTPS-Only Mode, the privacy report, how-to pages, Privacy Shield, and image export stay free.
- Launch upgrade candidates: local image Export As, saved session collections, and extra appearance presets. These are proposals, not yet implemented or sold.
- Website location is user controlled: Ask (default) or Never in Settings, Privacy, with Allow or Don't Allow remembered per site and listed in Settings so it can be undone. Private tabs ask every time and remember nothing. Location goes only to the site the user allows, never to Zalla, and Zalla keeps no copy. Typing a city for local search remains separate and never uses GPS. Every protection keeps a toggle, and defaults stay private.
- App icon quick actions (New Tab, New Private Tab, Search, Bookmarks, Burn It All) have a Settings switch, and Burn It All from the icon only ever opens its confirmation.
- Default browser: Zalla declares the http and https URL types and opens incoming web links in a new tab, but the `com.apple.developer.web-browser` entitlement stays out of the build until Apple approves the request (`docs/DEFAULT_BROWSER.md`). The Settings row says plainly that the choice depends on that approval.
- Video Saver (Zalla Unlock, with a Settings switch) saves videos a page serves as plain files through the normal download manager. It never saves protected video (FairPlay, Widevine, PlayReady, encrypted HLS), has no website specific code, and does not capture in-memory (blob) streams, to stay inside App Store Review Guideline 5.2.3. HLS download for clear streams is a roadmap item (`docs/VIDEO_SAVER.md`).
- Widgets (Search, Favorites, Burn It All, Privacy Report, and Lock Screen versions) follow the accent and are customizable in the widget editor. They read one small note the app writes into the App Group: accent, favorites the person already has, and Privacy Report totals. No history, no tab URLs, nothing from private tabs, no network. A Settings switch stops the sharing and erases the note. Burn It All from a widget only opens its confirmation. Zalla has no tracker blocked counter, so the Privacy Report widget shows links cleaned, HTTPS upgrades, and banners closed. See `docs/WIDGETS.md`.
- System credential integration should be tested on real devices; never claim password-manager compatibility before verifying it.

## Delivery sequence
1. **Foundation (current):** native browser source, tabs, library, sharing, appearance and local data controls. Compile and test on Mac next.
2. **Daily-driver reliability:** JavaScript dialogs and popups, downloads to Files, find on page, tab restoration/memory limits, permission UX, interrupted loading, accessibility, keyboard and landscape testing.
3. **Privacy and personalization:** maintained WebKit content rules with source/licensing review, per-site exceptions, accurate connection indicators, clean-link previews, toolbar placement and start-page controls. No invented trackers-blocked counters.
4. **Signature tools:** local image conversion with format/metadata tests, named sessions, then verified StoreKit purchase, restore, refund/revocation and offline entitlement behavior. No external purchase-validation backend required for the proposed model.
5. **Release:** device testing, TestFlight, accessibility/performance/security review, icon assets, public privacy policy and support URL, privacy disclosures, current SDK requirements, approved default-browser entitlement if pursued, App Review materials.

## Boundaries for privacy claims
Private tabs skip Zalla history and use WebKit nonpersistent website storage. They are not a VPN, tracker blocker, or guarantee of anonymity. Regular website storage is managed by WebKit. The app library is protected on disk and excluded from backup; OS-managed WebKit and preferences require separate backup/device validation. Do not describe all OS storage as guaranteed local-only until that validation is complete.

No safety, security, performance superiority, or complete browser parity is claimed by this prototype. The original handoff's broader feature list is a roadmap, not a release promise.

## Platform references checked September 21, 2026
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): system WebKit baseline and applicable review requirements.
- [WKWebsiteDataStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore): persistent versus nonpersistent website storage.
- [Default browser preparation](https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser): additional capabilities and entitlement requirements.
- [In-App Purchase](https://developer.apple.com/in-app-purchase/): one-time non-consumable purchases through StoreKit.
