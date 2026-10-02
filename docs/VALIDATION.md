# Validation and release gates

## Status
Source includes find-on-page (system find navigator via the browser menu) and native JavaScript alert/confirm/prompt panels (WKUIDelegate). These still need Mac/simulator validation with live pages.

Source review and file checks only on Windows.
 Native compilation, XCTest, visual verification, and device privacy tests have NOT been run. Do not treat this milestone as a tested binary.

## First Mac session
- Generate project, compile the app and tests; resolve all errors and investigate warnings.
- Run AddressResolverTests: empty input, HTTPS inference, explicit HTTP, query encoding, and executable/unsupported schemes.
- Browse HTTPS and HTTP pages, enter a search, follow same-window and target-blank links; verify redirects, back/forward, reload, stop, offline errors and invalid certificates.
- Switch tabs; verify each keeps its own page and back stack. Close selected/background/last tabs.
- Visit a distinctive URL in private mode, close the tab, relaunch; verify it never appears in history or the library file. Check private cookies do not persist or cross to regular tabs.
- Bookmark a page, relaunch, remove it; verify persistence. Force a storage failure and verify the error surfaces.
- Clear browsing data after setting cookies. Confirm tabs close, site login ends, history clears, bookmarks remain, and no pages recreate cookies in the background.
- Share a page; test Mail, Messages, Files and installed apps. Test telephone/email confirmation and cancellation. Arbitrary custom URL schemes are currently unsupported.
- Check app-switcher snapshots from both regular and private tabs on a physical iPhone.
- Test VoiceOver, large Dynamic Type, light/dark, keyboard, rotation, smallest supported iPhone screen, and low-memory behavior.

## Website location (Build 16)
Needs a physical iPhone. Check: Ask prompts once per site and remembers Allow and Don't Allow; Never blocks with no prompt; a private tab asks every time and a second visit asks again; Settings, Privacy, Location lists answers and swiping one away makes the site ask again; Reset the App and Burn It All clear the list; iOS Location Services off or While Using denied for Zalla leaves sites without a position and the page not hanging; behavior on iOS 17 to 26 (WebKit's own prompt) versus iOS 27 (Zalla's prompt).

## Menus and confirmations (Build 17)
Needs a physical iPhone. Check: Burn It All from the Menu, from Tabs, from the Quick Action fan, and from a Classic or Compact toolbar button each show a centered alert with Burn It All and Cancel (no popover, no arrow), and Burn It All closes the sheet and the app; Close All, Clear browsing data, Reset the App, Clear all downloads, Reset the report, and the Open another app question are centered alerts; Find on page from the Menu opens the find bar with the keyboard; Bookmark page shows a toast and the Menu closes; the Page Zoom sheet shows its footnote in full; Reset the new tab page in Settings, Home personalization asks first and the new tab page behind it updates; the search engine menu in setup is not doubled or clipped.

## Edge swipe, logo, transitions, Burn It All (Build 18)
Needs a physical iPhone. Check: swiping in from the left edge goes back and from the right edge goes forward on a loaded page, a new tab after a link, a tab you switched to, and after turning the Settings, Browsing switch off and on; the arrow follows the finger, a short swipe cancels, and the page still scrolls and the Quick Action fan, hold-reveal menu, and tab gestures still work near the edges; the logo on red, orange, pale, dark, and photo wallpapers under Auto, plus Zalla red, White, and Black; the saying and pencil read on every wallpaper; Jungle and Space transitions on reload and on Apply, at Slow, Normal, and Fast, with the switch off, and with Reduce Motion on (quick fade); Burn It All from the Menu, Tabs, and the fan shows flames from the edges, then closes, and the next launch is empty with nothing restored; force-quit during the flames and relaunch to confirm it is still wiped; battery and smoothness on an older iPhone.

## New tab page in history (Build 19)
Needs a physical iPhone. Check: open a new tab, load a site, swipe in from the left edge and land on the new tab page, then swipe in from the right edge (the thin strip) to return to the site; the same with the Back and Forward buttons in Classic, Compact, and Quick Action layouts, and the Menu; press and hold Back on the first page and see "New tab" last in the peek; press and hold Forward on the new tab page and see the page first; a tab opened from a link has no new tab page behind it; Back is dimmed on a blank new tab page; media stops when you step back to the new tab page; the swipe still respects the Settings, Browsing switch; Share and Add Bookmark are off while the new tab page is showing.

## Required before public beta
JavaScript alert/confirm/prompt support, downloads, file upload and system credential validation, camera/microphone permissions, memory management, content-process recovery, restoration policy, meaningful connection security UX, and explicit handling of unsupported content. Add targeted tests as these behaviors are implemented.

## Required before App Store submission
TestFlight feedback, final product scope, StoreKit sandbox tests if an upgrade ships, accurate privacy label/policy, app icon/screenshots, developer signing, supported SDK review, default-browser capability approval if included, support contact, and licensing review for any bundled rules or assets.
