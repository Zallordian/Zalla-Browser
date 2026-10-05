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
Needs a physical iPhone. Check: Burn It All from the Menu, from Tabs, from the Quick Action fan, and from a Classic or Compact toolbar button each show a centered alert with Burn It All and Cancel (no popover, no arrow), and Burn It All closes the sheet and, after the fire, leaves one fresh tab (the app stays open as of Build 32); Close All, Clear browsing data, Reset the App, Clear all downloads, Reset the report, and the Open another app question are centered alerts; Find on page from the Menu opens the find bar with the keyboard; Bookmark page shows a toast and the Menu closes; the Page Zoom sheet shows its footnote in full; Reset the new tab page in Settings, Home personalization asks first and the new tab page behind it updates; the search engine menu in setup is not doubled or clipped.

## Edge swipe, logo, transitions, Burn It All (Build 18)
Needs a physical iPhone. Check: swiping in from the left edge goes back and from the right edge goes forward on a loaded page, a new tab after a link, a tab you switched to, and after turning the Settings, Browsing switch off and on; the arrow follows the finger, a short swipe cancels, and the page still scrolls and the Quick Action fan, hold-reveal menu, and tab gestures still work near the edges; the logo on red, orange, pale, dark, and photo wallpapers under Auto, plus Zalla red, White, and Black; the saying and pencil read on every wallpaper; Jungle and Space transitions on reload and on Apply, at Slow, Normal, and Fast, with the switch off, and with Reduce Motion on (quick fade); Burn It All from the Menu, Tabs, and the fan shows flames from the edges, then closes, and the next launch is empty with nothing restored; force-quit during the flames and relaunch to confirm it is still wiped; battery and smoothness on an older iPhone.

## New tab page in history (Build 19)
Needs a physical iPhone. Check: open a new tab, load a site, swipe in from the left edge and land on the new tab page, then swipe in from the right edge (the thin strip) to return to the site; the same with the Back and Forward buttons in Classic, Compact, and Quick Action layouts, and the Menu; press and hold Back on the first page and see "New tab" last in the peek; press and hold Forward on the new tab page and see the page first; a tab opened from a link has no new tab page behind it; Back is dimmed on a blank new tab page; media stops when you step back to the new tab page; the swipe still respects the Settings, Browsing switch; Share and Add Bookmark are off while the new tab page is showing.

## Pull to refresh (Build 19)
Needs a physical iPhone. Check: scroll to the top of a long page, pull down, and see the spinner and a light haptic, then the page reloads and the spinner stops when it finishes; a pull that starts mid-page only scrolls; fast flicks up and down, horizontal scrolling, and pinch zoom never trigger it; the left and right edge swipes and the Quick Action fan, hold-reveal menus, and tab gestures still work; with the keyboard up (tap a search field on a page) a pull down puts the keyboard away and does not reload; the page sits correctly below the top bar while the spinner is out and settles back after (Classic, Compact, and Quick Action layouts, bars on top and bottom); with Jungle or Space on, a pull plays the same transition as the Reload button and Reduce Motion plays the fade; Settings, Browsing, Pull down to refresh off removes the spinner in every open tab right away and on again brings it back; a slow or offline page ends the spinner and shows the normal error page; private tabs and popups pull too.

## Jungle and Space polish (Build 19)
Needs a physical iPhone. Check: Jungle leaves look organic and uneven, in three layers that slide in back first and out front first with soft shadows and a gentle sway, and the screen is fully green at the middle; Space shows a sleek rocket with a long tapering flame, smoke puffs, a glow, and speed streaks, accelerating up the screen, with the warm wash covering the page and lifting away upward; both at Slow, Normal, and Fast; both off with the switch; Reduce Motion shows only the quick tint fade; no dropped frames or heat on an older iPhone; a quick second refresh restarts cleanly; the Apply preview in Theme packs plays the same transition.

## Burn It All fire (Build 19)
Needs a physical iPhone. Check: from the Menu, Tabs, and the fan, the page chars and darkens while yellow, orange, and red flame tongues rise, fill the screen, break apart into licks, and fade into small red-orange embers on black in about 2.5 seconds; then a plain "Clearing browsing data..." label with a small spinner on black (no box), then Zalla stays open on one fresh tab (Build 32; it used to close) and a relaunch is empty with nothing restored; force-quit during the flames and relaunch to confirm it is still wiped; Reduce Motion on, and Settings, Privacy, Burn It All fire effect off, each give a quick fade with the same label; frame rate and heat on an older iPhone (it should hold 60 frames a second), and the effect on an iPhone SE sized screen and in landscape.

## Burn It All, no second fire (Build 20)
Needs a physical iPhone. Check: after the flames fade to black and "Clearing browsing data..." appears, nothing grows from the bottom edge and there is exactly one label until the fresh tab appears; the same with Reduce Motion on and with Settings, Privacy, Burn It All fire effect off (fade, one label); from the Menu, Tabs, and the fan; relaunch is still empty. (Builds 18 to 31 closed the app here; Build 32 does not.)

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

## iPhone-only device family (Build 34)
After `xcodegen generate`, check `TARGETED_DEVICE_FAMILY = 1` for the Zalla, ZallaWidgets, and ZallaTests targets (Xcode Build Settings, or `xcodebuild -showBuildSettings`). In App Store Connect or TestFlight the build lists iPhone only, with no iPad. The iPad simulator is not offered as a run destination.

## Last Polish (Build 33)
Needs a physical iPhone. Check:
- Dialogs: open a page that fires alert(), confirm(), and prompt() in a loop, plus one that asks for camera, microphone, or location. While a dialog is up, close the tab, use Close All, run Clear browsing data, and run Burn It All. No crash and no stuck page each time. Answer a dialog normally and confirm it only fires once.
- Image export: long-press an image and open Export image. Only formats this phone can write are listed (PNG and JPEG always; HEIC and WebP only if supported). Save and Share work for each listed format.
- Alternate icon failure (for example in the simulator without icons) reads "Alternate icons aren't available right now."
- Settings, Tools: the row reads "Open Zalla settings in iOS" and opens Zalla's page in Settings. The footer does not promise a default browser choice.
- Zalla Unlock sheet: in airplane mode the product area says "Couldn't reach the App Store" with Try again; turning the network on and tapping Try again loads the price. Restore Purchases offline says it could not reach the App Store; online without a purchase says no previous purchase was found; with a purchase it says Zalla Unlock is active.
- Cookie banners: pages with a TrustArc banner are not accepted for you. The script no longer contains `.truste-button2`.
- Clear browsing data: tabs close, cookies and site data clear, Listen to page stops speaking, and the app lands on one new tab.
- Settings help text for Burn It All does not say it closes Zalla. How to entries name Settings, Appearance, Home personalization and Premium or Appearance, Explore theme packs.
- Purchases completed while Zalla was closed (Ask to Buy approval) finish at launch.
- Support Zalla offline: "Couldn't reach the App Store" with Try again; Try again loads the tips once online. An empty product list says tips (or Zalla Unlock) are not available right now, also with Try again.
- Dialog edge cases: with a Settings or Menu sheet open, let a page fire alert(); it is shown above the sheet, and dismissing the sheet while it is up never leaves the page frozen after the tab is closed. A page that loops alert() after its tab is closed shows no more dialogs.
- Frames: a page with an iframe using a data: or blob: source shows it. A download link to a blob or data file still downloads, from the page or from inside an iframe.
- VoiceOver on Add shortcut, Icon: choices read "Search", "Compass", "Lightning bolt", not symbol names.

## Burn It All stays open, Video Saver hidden (Build 32)
Needs a physical iPhone. Burn It All: confirm from the Menu, Tabs, Settings, the app icon quick action, and the Burn It All widget; the alert says Zalla opens a fresh tab and that bookmarks and downloads stay. The fire plays, the Clearing browsing data label shows once, then exactly one fresh new tab page appears and the app does NOT quit or flash the home screen. Check: all other tabs (including private ones and groups of tabs) are gone, any open sheet (Menu, Tabs, Settings, Bookmarks) is dismissed, history is empty, a site you were logged into asks you to log in again, its cookies and site data are gone, the page you burned from is not in Back, bookmarks and downloads are still there, and the back button is disabled on the fresh tab. Burn twice in a row, burn with a page loading, burn with a video or call playing (audio must stop), burn with a download running, then watch memory in Xcode: web content processes for the old tabs should disappear. Force-quit during the flames and relaunch: still wiped. Reduce Motion and Settings, Privacy, Burn It All fire effect off give the quick fade and the same fresh tab. Quick action and widget only ever open the confirmation.
Video Saver (off in v1 by `FeatureFlags.videoSaverEnabled`): on a page with a plain video file there is no Save video row in the Menu, Settings, Premium has no Video Saver section, the Zalla Unlock sheet does not list it, About, What's new has no Video Saver line, and the page does not post `zallaVideo` messages. Set the flag to true to bring everything back for 1.1.

## Privacy manifests and Unlock list (Build 31)

- Upload to App Store Connect (TestFlight): no "missing privacy manifest" or "missing required reason API" warnings for Zalla or ZallaWidgets.
- Settings, Premium, Zalla Unlock (and any Unlock upsell sheet): the Includes list shows "Video Saver for plain video files" after Listen to page, and every other row is still there.
- Archive check: `Zalla.app/PrivacyInfo.xcprivacy` and `Zalla.app/PlugIns/ZallaWidgets.appex/PrivacyInfo.xcprivacy` both exist.
- Widgets still show data (App Group access is unchanged).

## Ready to type and widget looks (Build 30)

Needs a TestFlight build on a device.

- Search widget, Zalla force quit first: tap it. Zalla opens with the cursor in the address bar and the keyboard up, with no second tap. Repeat with Zalla in the background on the new tab page, and with a page open (the address is selected, typing replaces it). Repeat in Classic, Compact, and Quick Action toolbars, address bar on top and on the bottom.
- Same checks from the app icon menu, Search.
- Search while Settings or the Tabs sheet is open: the sheet closes first, then the keyboard comes up.
- Open Zalla by tapping the Search widget while the phone was locked and unlocked right after: the keyboard still comes up.
- Settings, Tools, Widgets, "Open search with keyboard ready" off: the Search widget and the icon Search just open Zalla. The explanation line about typing is shown.
- Wait a few seconds after opening Zalla normally, then open a new tab: the keyboard does not appear on its own.
- Widget editor: Look offers Accent gradient, Midnight, Aurora, Glass, Paper for Search, Favorites, Privacy Report. Burn It All keeps its ember look. Each is readable (no clipped text) in light and dark, with Larger Text on, and with Reduce Transparency on.
- Accent gradient follows the app accent (try a yellow custom accent: dark text stays readable). A fixed color in the editor overrides it.
- Favorites: colored tiles with the saved icon, or the first letter for plain shortcuts. Medium shows 4, large shows up to 8 plus a search bar that opens Zalla ready to type. Empty list shows "Nothing pinned yet".
- Burn It All: tap opens only the confirmation. Privacy Report: big number and ring match Settings, Privacy Report totals; with no data it says to open Zalla.
- Home Screen, Customize, Tinted: all widgets still look right (no unreadable shapes). Lock Screen Search and Privacy Report accessories still work.
- Settings, Tools, Widgets: the Preview look picker redraws the previews.

## Widgets (Build 29)

Needs the Apple Developer portal steps in docs/WIDGETS.md done first, then a TestFlight build on a device.

- Open Zalla once so it writes its snapshot, then add each widget from the gallery: Search (small, medium), Favorites (medium, large), Burn It All (small), Privacy Report (small, medium). Lock Screen: Search (circular, rectangular), Privacy Report (rectangular).
- Search: tapping opens Zalla with the address bar focused and the keyboard up, Zalla closed and running. Lock Screen versions open Zalla after unlock.
- Favorites: shows your home shortcuts, tapping a tile opens that site in a new Zalla tab. Edit Widget: switch Favorites to Bookmarks, change how many (large shows up to 8, medium up to 4), hide titles. With none, it shows "No favorites yet".
- Burn It All: tapping opens the Burn It All confirmation. Cancel leaves everything. It never burns without confirming.
- Privacy Report: counts match Settings, Privacy Report totals after you open and background Zalla. Before any data exists, a plain "Open Zalla to start your report" shows.
- Accent: change the accent or custom color in Settings, Appearance, background Zalla, and the widgets (set to Follow Zalla) update. A fixed color in Edit Widget ignores the app accent. Soft look is tinted, Filled is solid, a light accent such as yellow uses dark text.
- Settings, Tools, Widgets: steps are shown, previews match the widgets, "Share with widgets" off erases the snapshot (widgets show empty states), on restores it.
- Private tabs: open a private tab and visit sites. No widget shows any address or count from it. Reset Zalla clears the snapshot.
- Airplane mode: widgets look the same (they never use the network).

## Quick actions, default browser, Video Saver (Build 29)

- Press and hold the Zalla icon on the Home Screen: New Tab, New Private Tab, Search, Bookmarks, Burn It All appear with their icons.
- Zalla closed (swipe it away first): choose each action. New Tab shows a blank tab. New Private Tab opens a private tab (Face ID first if the private lock is on). Search opens with the keyboard up in the address bar, in Classic, Compact, and Quick Action toolbars. Bookmarks opens the Library. Burn It All opens the confirmation and never burns until you confirm it. Cancel leaves everything as it was.
- Zalla running with a sheet open (Settings, Tabs): choose Search and Burn It All from the icon. The sheet closes first, then the bar focuses or the confirmation appears.
- Settings, Tools, Quick actions on the app icon off: the menu items just open Zalla and do nothing else.
- Tap a link to a website from Messages or Notes: with Safari still default nothing changes. Settings, Tools, Open Zalla settings in iOS (Make Zalla your default browser before Build 33) opens the Zalla page in the Settings app. The footer says the default browser choice depends on Apple's approval.
- After the entitlement is approved and enabled (docs/DEFAULT_BROWSER.md): Default Browser App lists Zalla. Links from other apps open in a new Zalla tab, with Zalla closed and with it running, and only web (http, https) links open.
- Video Saver, Zalla Unlock on: open a page with a plain MP4 (a direct file URL in a video tag). The Menu shows Save video, the page list shows the file, Save starts a download that appears in Downloads, then Open and Share work. Without Unlock the row shows a lock and opens Zalla Unlock.
- A page whose player is protected (a streaming service) shows no saveable file. If the page reports a key system only, Save video shows "This video is protected and can't be saved." Nothing is downloaded.
- An HLS (m3u8) link: Check stream explains it (stream, live, or protected) and downloads nothing.
- Settings, Premium, Video Saver off: the Save video row never appears. Private tabs: a saved video is marked Private in Downloads.

## Smooth motion (Build 28)

Compare against Safari side by side where you can. Run once normally, then once with Settings, Accessibility, Motion, Reduce Motion on.

- Address bar: tap the Compact pill. It expands with a spring and the side buttons slide away. Cancel, submit, and tap outside collapse it the same way. Quick Action and Classic bars behave the same. The bar slides with the keyboard.
- Reload and Stop swap with a short morph while a page starts and finishes loading. The loading bar eases forward without jumping.
- Quick Action fan: opens with a spring and fades the dim background, closes smoothly without a pop. Press and hold the search pill: the page info bubble scales in and fades out.
- Toast (for example after copying a link) fades in with a small drop and fades out. The element picker banner fades.
- Tabs: open the tab grid. Close a tab: the others shift with a spring and the closed card slides left. Drag a card left: it follows your finger and fades. Release early: it springs back. Flick it quickly: it closes. Swipe up still closes. The Tab closed bar slides up from the bottom and Undo works. New tab: the card scales in.
- Pages: open a link. The page eases in without a hard swap, the top strip does not jump, and the page does not shift (no change to the web view frame or the safe area). Back and forward by edge swipe: the arrow follows the finger and settles with a spring. Pull to refresh still works.
- New tab page fades in when you open a tab, switch to one, or close the last page.
- Settings: tap a category. The page glides across and the underline slides to the tab. Swipe between pages: the underline follows. Turn on Custom accent: the color controls ease open and closed. Tap a Quick theme swatch: it scales up with a checkmark popping in. Tap an app icon: it scales up. Library: Bookmarks and History cross fade.
- Reduce Motion on: nothing slides, scales, or springs. Quick fades of about a tenth of a second are fine. The status bar strip still follows the page, and the light and dark flip still waits a moment (Build 27).
- No new haptics. The Burn It All effect and theme transitions look exactly as before.

## Seamless status bar strip (Build 27)

Run on a device in the default immersive layout with Settings, Appearance, Status bar matches the page on.

- Reddit (dark header): the area behind the clock and battery is the same black as the header, with no border or bezel. Scroll down and up: the strip stays solid, with no flicker or jump, and the header scrolls like on a normal website.
- YouTube in dark mode: the header and the clock area look continuous while scrolling. Open a video and go back, search, and open a channel. The strip follows the page without flashing white.
- Sites with a header that slides away on scroll down and returns on scroll up (or becomes sticky): the strip color follows what is at the very top of the page within about a tenth of a second.
- Navigate between a light site and a dark site: the strip eases over in a quick blink (about 0.15 s), with no white or red flash while the new page loads.
- Show and hide the keyboard (tap a search field): the strip does not change or jump.
- Pull the page down past its top (rubber band): the strip color shows above the page, no gap or white band.
- A page with mid gray at the top: the clock text does not flip back and forth while you scroll.
- Light page: dark clock text. Dark page: light clock text. The whole app does not flicker between light and dark while scrolling.
- Settings, Appearance, Status bar matches the page off: the strip is the plain Zalla background. Explicit Light or Dark appearance is never overridden.
- New tab page and the Classic layouts look the same as in Build 26.

## Neon City, Arctic, and Cherry Blossom (Build 26)
Needs a physical iPhone. Check: without Zalla Unlock the three packs and their Quick theme swatches show a lock and open the Unlock sheet; with it, a swatch or Apply sets accent, icon, new tab background, and plays the transition; the home screen icons show the Z mark on a neon skyline, in ice with snow, and in blossom pinks; Neon City shows a dark wipe with a magenta front and cyan back edge, stuttering tubes, glow streaks, and scanlines, and the page is fully covered at the middle; Arctic grows ice from the corners until the screen is frozen, glints and snow show, then it melts back; Cherry Blossom shows a pink wash and a swirl of petals crossing left to right; each at Slow, Normal, and Fast, with Theme transitions off, and with Reduce Motion on (quick tinted fade); the Quick theme swatches (11) wrap onto three rows with no clipped names at large Dynamic Type; the new tab backgrounds read well; no dropped frames or heat on an older iPhone.

## Tabs and Share swapped (Build 26)
Needs a physical iPhone. Check: on a fresh install the Compact bar shows Back, Forward, the address pill, Tabs, and the menu button, and the pill has no tabs icon of its own; Tabs opens the tab switcher and its long press menu works; the Menu sheet top row shows Back, Forward, Reload, Share, Settings and Share opens the share sheet from inside the Menu (and is dimmed with no page URL); Classic and Quick Action bars look as before; updating from Build 25 with the default Compact bar shows Tabs in place of Share, a customized Compact bar and a customized Menu row stay exactly as they were; Settings, Appearance, Customize Toolbar and Customize Menu Row show the new defaults, reset to them, and can put Share or Tabs back anywhere; the Settings preview of the Compact bar matches.

## Quick theme (Build 25)
Needs a physical iPhone. Check: in Settings, Appearance, tapping Volcano, Deep Ocean, Retro Arcade, Jungle, or Space with Zalla Unlock changes the accent, the home screen icon, the new tab background, and plays the transition; without Unlock the locked swatches show a lock, open the Unlock sheet, and change nothing; Space without Unlock only sets the accent and offers the icon; Zalla Red, Ocean, Forest, and the More accents still set the accent and offer the matching icon; a swatch tap turns Custom accent off; Themes apply the full look off makes every tap accent only; Theme transitions off or Reduce Motion are respected by the preview; the Explore theme packs row still opens Theme packs.

## Header Room (Build 24)
Needs a physical iPhone. Check: on m.youtube.com the logo and search icon show on a normal load, after a refresh, and while scrolling up and down (the header sits right under the clock, the strip color matches it); other fixed or sticky headers (Reddit, Amazon, news sites) are visible too; no extra gap between the clock and the page top, and none under a top address bar or the app banner; pull down to refresh still shows the spinner and reloads; opening a page from the new tab page and the strip color changing as the page color arrives does not make the page jump; Reader, error pages, and private tabs look right; Immersive layout off, and Status bar matches the page off, still behave as in Build 23.

## Floating bottom bar (Build 23)
Needs a physical iPhone. Check: with Immersive layout on there is no frosted box behind the bottom controls; in Classic, Back, Forward, Share, Tabs, the address, and the menu are separate glass shapes with the page showing between them; in Compact and Quick Action the circles and pill float the same way; taps in the gaps go to the page (scroll, tap a link right above the bar); everything is a bit smaller than Build 22 and the bottom gap is still about 12 pt above the home indicator; the keyboard, landscape, and a bar on top still work; Immersive layout off brings back the solid bars.

## Status bar matches the page (Build 23)
Needs a physical iPhone. Check: on YouTube the logo is no longer under the clock and the top strip matches the page; light pages show dark clock text and dark pages light text; pages with a theme-color meta tag use it, others use their body color; the strip color animates when a page changes its theme-color or switches to dark mode; Reader and error pages look right; the new tab page keeps its full bleed wallpaper with the light fade; Settings, Appearance, Status bar matches the page off keeps content under the clock the Build 22 way (or the Zalla background in the strip) and does not recolor it; explicit Light or Dark appearance is respected; no flicker while scrolling.

## App banners (Build 23)
Needs a physical iPhone. Check: on a page with an apple-itunes-app tag (YouTube, Reddit, Amazon) a slim banner appears under the status bar with the app name, Open, and X; Open launches the installed app on that page, and with the app not installed the banner just hides (no App Store, no browser jump); X hides it for that host until Zalla is quit, other hosts still show it; private tabs show the banner but forget dismissals; the page moves down with the banner and back when it goes; Settings, Browsing, App banners off hides it everywhere; no network request to Apple.

## Volcano, Deep Ocean, and Retro Arcade (Build 23)
Needs a physical iPhone. Check: without Zalla Unlock the three packs show a lock and Apply opens the Unlock sheet; with it, Apply sets accent, icon, and new tab background; the home screen icons show the Z mark in ember, aqua, and arcade colors; Volcano lava rises with sparks and clears upward, Deep Ocean's wave rolls across and pulls back with bubbles and light rays, Retro Arcade dissolves into pixels with scanlines and a scan bar and clears; each at Slow, Normal, and Fast, with Theme transitions off, and with Reduce Motion on (quick tinted fade); a reload and a pull to refresh play them; the new tab backgrounds read well in the light and dark text styles; no dropped frames or heat on an older iPhone.

## Required before public beta
JavaScript alert/confirm/prompt support, downloads, file upload and system credential validation, camera/microphone permissions, memory management, content-process recovery, restoration policy, meaningful connection security UX, and explicit handling of unsupported content. Add targeted tests as these behaviors are implemented.

## Required before App Store submission
TestFlight feedback, final product scope, StoreKit sandbox tests if an upgrade ships, accurate privacy label/policy, app icon/screenshots, developer signing, supported SDK review, default-browser capability approval if included, support contact, and licensing review for any bundled rules or assets.
