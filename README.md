# Zalla

**Built around you.** A free, privacy-conscious iPhone browser, with optional creative tools planned as a one-time lifetime unlock around US $1.

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

No external SDKs, analytics, account service, Zalla backend, or purchase flow. There is no tracker blocker yet. Tabs are not restored after termination. Each private tab is isolated, so logins are not shared across private tabs. Explicitly bookmarking or sharing a private page is a user-directed export.

## Build on a Mac

1. Install Xcode with the iOS SDK and XcodeGen (https://github.com/yonaskolb/XcodeGen).
2. In this folder run `xcodegen generate` and open `Zalla.xcodeproj`.
3. Select the Zalla scheme and an installed iPhone simulator; build and run.
4. Run the ZallaTests target with Product → Test.
5. For a physical iPhone, choose your Apple development team in Signing & Capabilities and replace the placeholder bundle identifier with one you control.

The project specification generates Info.plist. The web-content-only App Transport Security exception permits user-requested HTTP websites; native app network requests retain platform defaults. TLS failures use WebKit's default handling. The [icon kit](docs/branding/icons/README.md) includes a configured app icon catalog, appearance variants and development exports; Mac/device validation and native Icon Composer adoption remain release work. Default-browser entitlements, signing, and App Store metadata are intentionally still release work.

See [product direction](docs/PRODUCT.md) and [device validation](docs/VALIDATION.md). The original project handoff remains unchanged.
