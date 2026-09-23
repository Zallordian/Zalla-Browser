# Product direction

## Mission
Make a premium, useful gateway to the internet available without selling user data. Zalla operates without its own backend. Internet access still depends on the user's network; browsing contacts websites and search providers, and purchases will contact Apple.

## Working decisions
- Zalla / “Built around you.” / crimson brand, as recorded in the original handoff.
- iPhone first, native SwiftUI and system WebKit. iOS 17 is a provisional minimum.
- No account, analytics SDK, advertising SDK, proprietary credential vault, or cloud sync.
- Core browsing and meaningful privacy controls remain free.
- Proposed lifetime upgrade around US $1, using a StoreKit non-consumable. Final localized price comes from App Store Connect and StoreKit, not a hardcoded price. No subscription.
- Launch upgrade candidates: local image Export As, saved session collections, and extra appearance presets. These are proposals, not yet implemented or sold.
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
