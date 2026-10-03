# Default browser

Zalla is prepared to be chosen as the default browser, but the choice only works once Apple approves the entitlement for it. Until then the app behaves exactly as before and Safari stays the default.

## What is already in the build (Build 29)
- `project.yml` declares the `http` and `https` URL types for the app (`CFBundleURLTypes`, second entry, name `com.zalla.browser.web`). This is harmless without the entitlement.
- Incoming web links are handled in `ZallaApp.swift` with `onOpenURL`, which calls `BrowserStore.openIncoming`. It reuses a blank new tab or opens a new one. It works for a cold launch and a warm launch, and only `http` and `https` addresses are ever opened (`IncomingLink.webURL`). Links with other schemes are dropped.
- Settings, Tools has a row "Make Zalla your default browser". It opens the Settings app page for Zalla (`UIApplication.openSettingsURLString`). The wording says the Default Browser App choice appears there only once Apple has approved Zalla.

## What is NOT active
The entitlement `com.apple.developer.web-browser` lives in `config/Zalla-DefaultBrowser.entitlements`. Nothing points at that file. An entitlement that Apple has not approved for the App ID makes the provisioning profile invalid and breaks signing, so it must stay out of the build until approval.

## How to switch it on after Apple approves
1. Apple emails the approval for the App ID `com.zalla.browser`. In the Apple Developer portal, Certificates, Identifiers and Profiles, open the App ID. The Default Browser (Web Browser) capability is now available. Enable it and save.
2. In `project.yml`, under target `Zalla`, add the entitlement to the entitlements properties. If the target has no `entitlements:` block yet, add one:
   ```yaml
       entitlements:
         path: config/Zalla.entitlements
         properties:
           com.apple.developer.web-browser: true
   ```
   If the block already exists (Build 29 widgets add one for the App Group), add the single line `com.apple.developer.web-browser: true` under its `properties`. `config/Zalla-DefaultBrowser.entitlements` is the reference for the exact key.
3. Let Codemagic create a new App Store profile. With automatic signing through the App Store Connect integration the profile is regenerated when the App ID changed. If the old profile is cached, delete it in the portal first.
4. Build, install on a device, then open Settings, Zalla, Default Browser App, and pick Zalla. Tap a link in Messages or Mail and confirm it opens in a new Zalla tab, both with Zalla closed (cold) and running (warm).

## Review notes
- A default browser app must use WKWebView for web browsing. Zalla does.
- The request is a form on Apple's site, not a capability toggle. The draft text is in `zalla-notes/launch/default-browser-request.md` (outside this repo).
- Apple's reference: Preparing your app to be the default browser (developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser).
