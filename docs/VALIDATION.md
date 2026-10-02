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

## Pull to refresh (Build 19)
Needs a physical iPhone. Check: scroll to the top of a long page, pull down, and see the spinner and a light haptic, then the page reloads and the spinner stops when it finishes; a pull that starts mid-page only scrolls; fast flicks up and down, horizontal scrolling, and pinch zoom never trigger it; the left and right edge swipes and the Quick Action fan, hold-reveal menus, and tab gestures still work; with the keyboard up (tap a search field on a page) a pull down puts the keyboard away and does not reload; the page sits correctly below the top bar while the spinner is out and settles back after (Classic, Compact, and Quick Action layouts, bars on top and bottom); with Jungle or Space on, a pull plays the same transition as the Reload button and Reduce Motion plays the fade; Settings, Browsing, Pull down to refresh off removes the spinner in every open tab right away and on again brings it back; a slow or offline page ends the spinner and shows the normal error page; private tabs and popups pull too.

## Jungle and Space polish (Build 19)
Needs a physical iPhone. Check: Jungle leaves look organic and uneven, in three layers that slide in back first and out front first with soft shadows and a gentle sway, and the screen is fully green at the middle; Space shows a sleek rocket with a long tapering flame, smoke puffs, a glow, and speed streaks, accelerating up the screen, with the warm wash covering the page and lifting away upward; both at Slow, Normal, and Fast; both off with the switch; Reduce Motion shows only the quick tint fade; no dropped frames or heat on an older iPhone; a quick second refresh restarts cleanly; the Apply preview in Theme packs plays the same transition.

## Burn It All fire (Build 19)
Needs a physical iPhone. Check: from the Menu, Tabs, and the fan, the page chars and darkens while yellow, orange, and red flame tongues rise, fill the screen, break apart into licks, and fade into small red-orange embers on black in about 2.5 seconds; then a plain "Clearing browsing data..." label with a small spinner on black (no box), then Zalla closes and the next launch is empty with nothing restored; force-quit during the flames and relaunch to confirm it is still wiped; Reduce Motion on, and Settings, Privacy, Burn It All fire effect off, each give a quick fade with the same label; frame rate and heat on an older iPhone (it should hold 60 frames a second), and the effect on an iPhone SE sized screen and in landscape.

## Burn It All, no second fire (Build 20)
Needs a physical iPhone. Check: after the flames fade to black and "Clearing browsing data..." appears, nothing grows from the bottom edge and there is exactly one label until Zalla closes; the same with Reduce Motion on and with Settings, Privacy, Burn It All fire effect off (fade, one label); from the Menu, Tabs, and the fan; relaunch is still empty.

## Settings tabs (Build 21)
Needs a physical iPhone. Check: Settings opens on the last tab you used; tapping a tab and swiping sideways both change it and the strip keeps the selected tab in view; every old setting is still there (compare against the Build 20 list: Appearance, Toolbar, Address bar, Customize Toolbar, Home personalization, accent swatches, Theme packs, custom accent controls, app icon grid, search engine, bookmark import and export, Sleep unused tabs, edge swipe, pull to refresh, Tools links, every Privacy row, Our promise, Support Zalla, policy and support links, About, version); the Premium tab shows Zalla Unlock and opens the sheet, Face ID for private tabs and Auto-clear work there; the Privacy "What these do" row expands; Dynamic Type at the largest and accessibility sizes (strip scrolls, nothing clipped); VoiceOver reads each tab with Selected and swipes between rows; Reduce Motion on (no sliding); light, dark, and several accents (underline follows the accent); the sheet still drags down to close and the keyboard with the hex field still dismisses; Reset the App returns to the Appearance tab.

## Immersive layout (Build 22)
Needs a physical iPhone (a model with a home indicator, and one without if possible). Check: with Settings, Appearance, Immersive layout on (default), the page runs under a transparent status bar and to the very bottom edge with no strip behind the bar; the bar is a frosted capsule a slim gap above the home indicator in Classic, Compact, and Quick Action, and with the address bar on top it floats just under the status bar; the last line of a long page scrolls clear of the bar with no jump when the bar hides and shows; the status bar text stays readable over a dark page and a white page in light and dark mode; the new tab page, Reader mode, the find bar, error and HTTPS notice pages, pull to refresh, left and right edge swipes, the keyboard (the bar rides above it), the Quick Action button and fan, and the hold-reveal menu all still work; rotate to landscape; with the switch off the solid bars return and the gap under them is a little smaller than Build 21; toggling while a page is open applies right away; Reset the App turns it back on.

## Menu top row (Build 22)
Needs a physical iPhone. Check: the Menu top row shows Back, Forward, Reload, Tabs, and a Settings gear by default and each opens what it says; Settings, Appearance, Customize Menu Row adds, removes, reorders, and resets, with a six button limit and at least one button; Share, Bookmark, Find on page, New tab, Burn It All (asks first), Downloads, and Home each work from the row, and Home shows the new tab page with Forward returning to the page; buttons dim when they do not apply (no page, no URL); large Dynamic Type and VoiceOver read the row; the lower Menu sections still hold every action; Reset the App restores the default row.

## Settings tab strip polish (Build 22)
Needs a physical iPhone. Check: tabs are easy to hit with a thumb; the selected tab slides to the center of the strip on tap and on swipe; a light tap on each change, and none with Settings, Appearance, Haptic tap on Settings tabs off; the edge fades appear only on the side with more tabs and vanish when everything fits; Done stays reachable; Reduce Motion, VoiceOver, and large text still behave.

## Burn fire look (Build 22)
Needs a physical iPhone. Check: flames have soft curved edges and a warm gradient from a hot base to a deeper tip, the front lemon core has a gentle glow, embers include dots, sparks, and flakes, timing is the same as Build 21 (about 2.4 seconds, black and one label at the end, no replay), and it still holds 60 frames a second and stays cool on an older iPhone; Reduce Motion and the Privacy switch still give the quick fade.

## Required before public beta
JavaScript alert/confirm/prompt support, downloads, file upload and system credential validation, camera/microphone permissions, memory management, content-process recovery, restoration policy, meaningful connection security UX, and explicit handling of unsupported content. Add targeted tests as these behaviors are implemented.

## Required before App Store submission
TestFlight feedback, final product scope, StoreKit sandbox tests if an upgrade ships, accurate privacy label/policy, app icon/screenshots, developer signing, supported SDK review, default-browser capability approval if included, support contact, and licensing review for any bundled rules or assets.
