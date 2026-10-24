# Zalla build history

The in-app What's new shows only the public 1.0 entry. This is the full TestFlight history it replaced, kept for reference.

## Build 42: Safari Style Bar
- New default bottom bar in the style of Safari on iOS 26: slim (48 points), floating over the page with no band or separator
- Back, Forward (faded when there is nothing to go forward to), a pill with the bold page title over the lock and domain, reload inside the pill, Tabs, and More
- Closer to the screen edges with even spacing, and every change animates with one spring
- Loading shows as a thin line inside the pill, so the bar never shifts while a page loads
- Settings, Toolbar and Tabs, Bar Layout: Safari style or Classic. Classic brings back the earlier bars
- Customize Toolbar edits the Safari style buttons, and the accent color still tints Back and Forward

## Build 41: New Menu and Settings
- The Menu opens as a card that follows Light and Dark mode, with your real privacy numbers at the top
- My actions grid with Bookmark, History, Burn It All, and New Private Tab by default, up to 8, editable
- Page tools, Show All for the rest, then Bookmarks and History, Downloads, Tabs and Tab Groups, and All Settings
- Settings is one list in clear groups: Features, General, Privacy, Display, Toolbar and Tabs, Tools, Support and About
- Address bar placement picked from two small pictures, plus a Page Zoom list to forget saved zoom per site
- Haptic tap on Settings tabs removed with the tab strip
- Every existing setting keeps its saved value

## Build 40: Launch Ready
- Version back to 1.0 so this build can go with the 1.0 App Store submission
- Bookmarks are never overwritten when the library cannot be read, and an unreadable file is copied aside
- Library and downloads saves work while the iPhone is locked
- Export image uses the tab's own cookies and your proxy, and keeps nothing in a shared cache
- Image hold runs in Zalla's own script world and only on the top page
- Blocking is ready before the restored tab loads after launch
- Downloads cut off by closing Zalla show as stopped, with Retry
- The privacy cover shows only once Zalla is really in the background, with a switch in Settings
- What's new shows one 1.0 entry; this file keeps the build history
- Plainer Encrypted DNS wording; turning it on applies right away
- Private tabs close cookie banners too

## Build 39: Steady Hands
- Export image only opens when you really press and hold a picture. Scrolling through shopping pages and swiping carousels no longer pops it up
- Coming back to Zalla after a while brings your page right back, without an error

Improvements: Typing in a search box on a page brings the full toolbar back, and notices always sit above the toolbar.

Fixes: No more "Frame load interrupted" message when a link opens an app or starts a download.

## Build 38: Clear View
- When the toolbar folds into the small pill, the gray bands at the top and bottom of the screen now fade away too, so the page fills the whole screen behind the pill

## Build 37: Easy Reach
- When the toolbar folds into the small pill, the pill now rises a little as it shrinks, so it sits clear of the home bar at the bottom of the screen. Tapping it brings the toolbar back instead of sending you home

Improvements: The site's name sits right in the middle of the small pill.

## Build 36: Smooth Scroll
- The bottom toolbar now folds away smoothly while you scroll. The buttons fade out as the address bar narrows into a small pill with the site's name, all in one motion, and it opens back up the same way

Improvements: Tap the small pill to bring the full bar back. With Reduce Motion on, the bar simply fades between the two looks.

Fixes: The address bar no longer jumps or snaps when the toolbar folds away or comes back.

## Build 35: Room to Read
- Pages now run all the way to the top of the screen, under the clock and battery, like in Safari. A site's own header still starts below the clock. This needs iOS 26 or later and the address bar at the bottom; you can turn it off in Settings, Appearance, Page under the status bar
- The bottom toolbar shrinks to a small address pill while you scroll down a page, so you see more of it. Scroll up, reach the top or the end of the page, or tap the pill to get the full bar back. Settings, Appearance has a switch called Collapse toolbar while scrolling

Improvements: The toolbar stays put while you type in the address bar, on short pages, and with Quick Action. With Reduce Motion on it changes without the spring.

## Build 33: Last Polish
- Restore Purchases now tells you when it could not reach the App Store, instead of saying no purchase was found. If Zalla Unlock or the tip jar cannot load, you get a Try again button
- Saving or sharing an image only lists the formats your phone can actually create

Improvements: Settings wording is plainer: the Burn It All help matches what it really does, the Settings shortcut row is called Open Zalla settings in iOS, and the How to steps point to the right Settings screens. Clear browsing data now also clears cached files and lets go of open tabs, like Burn It All does.

Fixes: Closing a tab, or burning, while a page is asking a question (an alert, a camera or location request) is handled cleanly. If the app icon cannot be changed, the message is now short and plain. Pages that show content in a frame from a data or blob address now load instead of turning into a download. The icon choices for a new tab shortcut have readable names for VoiceOver.

## Build 32: Fresh Start
- Burn It All no longer closes Zalla. It plays the fire and erases tabs, history, cookies, and site data exactly as before, then drops you on one fresh tab, ready to use. Bookmarks and downloads stay put

Improvements: Burn It All closes any open sheet, lets go of the old pages so nothing from them is kept in memory, and forgets the app banners you dismissed.

## Build 31: Paperwork
- Privacy details for Zalla and its widgets are filled in for Apple: the only thing either reads is its own small settings, and the widgets read only the note Zalla shares with them on your phone

Fixes: App Store checks no longer flag the widgets for a missing privacy declaration.

## Build 30: Ready to Type
- Tap Search on the widget (or Search in the app icon menu) and Zalla opens with the cursor already in the address bar and the keyboard up. It works from a cold start and when Zalla is already running. If you would rather it just open, there is a switch in Settings, Tools, Widgets
- The widgets got a makeover. Five looks to pick from in the widget editor: Accent gradient (the default, it follows your Zalla accent), Midnight, Aurora, Glass, and Paper. Search has a proper rounded bar, favorites are colored tiles with their icon or first letter, Burn It All glows like embers, and Privacy Report has a big number and a ring
- Widgets also behave on a tinted Home Screen and on the Lock Screen, and they follow light and dark

Improvements: Settings, Tools, Widgets explains why a widget can open Zalla ready to type but cannot take typing itself, and the previews can try each look.

Fixes: The Search quick action no longer depends on the address bar already being on screen, so it works on a cold launch too.

## Build 29: Press and Hold
- Press and hold the Zalla icon for quick actions: New Tab, New Private Tab, Search, Bookmarks, and Burn It All. Burn It All only opens its usual confirmation, it never burns on its own. There is a switch in Settings, Tools if you would rather the icon menu just open Zalla
- Widgets for the Home Screen and Lock Screen: Search, Favorites, Burn It All, and Privacy Report. They follow your Zalla accent by default, and in the widget editor you can pick another color, a softer look, and which favorites to show. Widgets never use the network and never see your history. Settings, Tools, Widgets explains how to add them, and has a switch to stop sharing
- Zalla is ready to become your default browser. Settings, Tools has a Make Zalla your default browser row that opens its page in the Settings app, and Zalla opens web links you send it in a new tab. Choosing it as the default browser works only once Apple approves Zalla for it, so the choice may not appear yet

Improvements: Links that open Zalla work whether it was closed or already running.

## Build 28: Smooth Moves
- Everyday motion now feels closer to Safari: springy, quick, and easy to interrupt. The address bar opens and closes with a spring, the Reload and Stop icon swaps with a little morph, the loading bar eases along, pages fade in as they commit, and the new tab page fades in instead of snapping
- Tabs move with a spring. Cards slide into place when one closes, a card follows your finger when you swipe it away (a quick flick works too, and a short swipe springs back), and the Tab closed bar slides up from the bottom
- In Settings, the underline under the category tabs slides to the next tab and the page glides across, the custom accent controls ease open, and a tapped theme swatch or app icon gives a little pop

Improvements: Every new animation follows Reduce Motion (no motion, or a short fade) and comes from one shared set of timings. Toasts, the Quick Action fan, and the edge swipe arrow also ease in and out.

## Build 27: Seamless Top
- The strip behind the clock and battery now matches what the page actually shows at its top edge, so a site like Reddit (black header) or YouTube in dark mode looks like one continuous page instead of a border. Pages scroll like a normal website, and the strip follows the page color as headers slide away or stick, without a flash while pages load

Improvements: The strip color eases over in a quick blink, tiny color shifts are ignored, and the clock and battery text no longer flip back and forth on mid gray pages. Pulling the page down past its top now shows the strip color instead of a gap.

Fixes: Fixed the top of the page looking off while scrolling on some sites, and the strip flashing white while a page was still loading.

## Build 26: Neon, Frost, Blossom
- Three more theme packs in Zalla Unlock: Neon City (magenta and cyan glow, with a flickering neon wipe and glow streaks), Arctic (ice blue, with frost that spreads in from the corners and snow sparkle), and Cherry Blossom (soft pinks, with a swirl of petals that sweeps across). Each has an accent, an app icon, and three new tab backgrounds, and they show up in Quick theme and Explore theme packs
- Tabs and Share traded places. The Compact bar now has Tabs next to the menu button, instead of Share, and the address pill no longer repeats the Tabs icon. The top row of the Menu now has Share instead of Tabs. If you never changed these, you get the new setup on its own. If you did, nothing moves, and Settings, Appearance still lets you put either one wherever you like

Improvements: The theme swatches in Settings, Appearance wrap onto three tidy rows. The new themes follow the same On and Off and Speed switches, and Reduce Motion plays the quick fade.

## Build 25: One Tap Theme
- Tapping a theme in Settings, Appearance now changes the whole theme, not just the color. Pick Volcano, Deep Ocean, Retro Arcade, Jungle, or Space and you get its accent, app icon, new tab background, and refresh transition in one go, with the transition playing right away. Locked themes show a lock and open Zalla Unlock instead of changing anything
- The row below is now Explore theme packs, for looking around the premium themes. The section is called Theme and accent, and the old Signature row is Quick theme

Improvements: Settings, Appearance, Themes apply the full look turns it off, so a tap only sets the accent like before. Free accents, Zalla Red as the default, and the custom accent still work the same, and picking a theme turns the custom accent off.

## Build 24: Header Room
- Fixed: a site's own header at the top of the page, like the YouTube logo and search icon, was hidden under the colored status bar strip. The page now starts right below the clock, so headers show up on a normal load

Improvements: Nothing changes with Immersive layout off, and the new tab page keeps its full bleed wallpaper.

Fixes: YouTube's top header no longer disappears on a normal load.

## Build 23: Float On
- The bottom bar now floats for real, like Safari on iOS 26. No frosted box behind it: the Back button, the address, and the menu button are each their own little glass shape sitting right on the page, with the page showing through the gaps. Classic, Compact, and Quick Action all float the same way, everything is about 12 percent smaller, and Settings, Appearance, Immersive layout still brings back the solid bars
- The page now starts below the clock instead of running under it, and the status bar area takes on the page's own color, so YouTube keeps its logo and the top looks seamless. Light pages get dark text and dark pages get light text. Settings, Appearance, Status bar matches the page turns it off
- App banners: when a site says it has an app (the same hint Safari reads), a slim banner under the status bar offers Open in the app. It only opens an app you already have, never goes to the App Store, and never calls Apple. Dismiss it and it stays away for that site until you quit Zalla. Settings, Browsing, App banners turns it off
- Three new theme packs in Zalla Unlock: Volcano (black and ember red, with a lava wipe and flying sparks), Deep Ocean (teal and aqua, with a wave that rolls across and pulls back, bubbles, and light rays), and Retro Arcade (pink, blue, and yellow pixel stars, with a CRT pixel dissolve). Each has an accent, an app icon, and new tab backgrounds

Improvements: The new themes play on refresh and when applied, follow the same On and Off and Speed switches in Settings, Theme packs, and get the quick fade when Reduce Motion is on. The new tab page keeps its full bleed wallpaper.

Fixes: The status bar clock and the YouTube logo are no longer hidden by the page.

## Build 22: Edge to Edge
- Pages now run edge to edge, under the status bar and down to the bottom of the screen, like Safari on iOS 26. The bar floats over the page as a frosted glass capsule just above the home indicator, and the page still scrolls clear of it. It works with Classic, Compact, Quick Action, and a bar on top. Settings, Appearance, Immersive layout turns it off for the solid bars
- The top row of the Menu is yours now: Back, Forward, Reload, Tabs, and a new Settings gear by default. Settings, Appearance, Customize Menu Row lets you pick and reorder, and adds Share, Bookmark, Find on page, New tab, Burn It All, Downloads, and Home
- Settings tabs are bigger, the one you pick slides to the middle, there is a small tap when it changes, and the edges fade when more tabs are hiding off screen

Improvements: The bar sits closer to the bottom edge, with a smaller gap under it, even with Immersive layout off. The Burn It All flames have softer curved edges, a glow in the bright core, and sparks and ash among the embers, with the same timing as before.

## Build 21: Settings, Sorted
- Settings is now a row of tabs across the top: Appearance, Privacy, Browsing, Tools, Premium, and About. Tap a tab or swipe sideways. Zalla remembers the one you were on
- The long explanation under Privacy now folds away under What these do. Face ID for private tabs and Auto-clear moved to the new Premium tab, next to a Zalla Unlock row and Theme packs

Improvements: Nothing was removed or renamed, and every switch keeps its setting. The tab names read aloud with the selected one announced, the strip scrolls at large text sizes, and Reduce Motion skips the sliding.

## Build 20: One Burn Is Enough
- Burn It All no longer lights a second, smaller fire at the bottom of the screen while it says Clearing browsing data. The flames burn out once, then it is just black and the label

Fixes: The Burn It All effect keeps its own clock, so it can no longer start over when the tabs close behind it.

## Build 19: Pull Down, Burn Up
- Burn It All has a new look: flames in yellow, orange, and red rise over your page, break apart into embers, and fade to black, then a plain Clearing browsing data label shows while it finishes, then you land on a fresh tab. Settings, Privacy has a switch if you prefer a quiet fade
- Pull down at the top of any page to reload it, with a spinner that stops when the page is done. It is on by default and has a switch in Settings, Browsing
- The new tab page is now the first page of every tab's history. Swipe back from your first site and you land on it, and swipe forward to return. The Back and Forward buttons and the history peek know about it too

Improvements: Jungle and Space got a glow-up: more organic leaves in layers that sway and cast soft shadows, and a sleeker rocket with a long tapering flame, smoke puffs, and a smoother climb. Same On and Off and Speed switches, and Reduce Motion still gets a quick fade.

Fixes: Going back from the first page no longer leaves you with nowhere to go.

## Build 18: Swipe, Sweep, Burn
- Swiping in from the screen edge now goes back and forward. It was supposed to before. It is now Zalla's own swipe, with a little arrow that follows your finger
- Jungle and Space got proper full-screen transitions: a leafy curtain and a rocket. Switch them off or set the speed in Settings, Theme packs
- Burn It All now lights the browser from the edges and burns it toward the middle before closing
- The Zalla logo on your new tab turns white or black when red would get lost. Logo style in Settings, Home lets you pick

Improvements: The saying, shortcut names, and the pencil on the new tab page now pick light or dark to read on your wallpaper. Reduce Motion gets a quick fade instead of the big effects. Burn It All finishes its wipe even if you close Zalla while the flames are going.

Fixes: Edge swipe now works on every tab, including new ones.

## Build 17: Menus that line up
- Burn It All now asks in the middle of the screen, not in a little popover at the top pointing at the wrong button
- Close all tabs, Clear browsing data, Reset the App, and the other are-you-sure questions ask the same way, each with a Cancel
- Bookmark page now tells you it worked

Improvements: Find on page opens its bar and keyboard once the Menu has closed. Page Zoom has room for its footnote. Downloads in Settings no longer has a Done button that only goes back. Resetting the new tab page asks first and updates the page right away. Editing a shortcut checks its address the way Add Shortcut does.

Fixes: The search engine menu in setup no longer repeats its own label.

## Build 16: Where You At
- Websites can now ask for your location, for weather, nearby coffee, and the occasional map. Zalla asks you first, every time or once per site, and the default is still Ask
- Prefer to stay unfindable? Settings, Privacy, Website location, Never. Sites get a polite no and you get no prompts
- Your location goes only to the site you allow. Not to Zalla, and not anywhere else. Private tabs ask every time and remember nothing
- Changed your mind? Settings, Privacy, Location lists every site you answered. Swipe one away and it has to ask again

Improvements: Burn It All and Reset the App now forget which sites you said yes or no to. Safety at a glance gets a Website location row. The Location page now says plainly that typing a city never uses GPS.

Fixes: The Location page no longer claims Zalla never asks iOS for your location, because now it can, if you say so.

## Build 15: Fewer Loose Ends
- The Flame is now Burn It All, and its icon wears your accent color. Find it in Tabs, the Menu, or add it to your Quick Action buttons
- Listen to Page keeps talking when you leave the app or lock your phone
- Zalla can now reach devices on your local network, like a printer page or a home server, when you open their address

Improvements: Bookmark import runs in the background and reads more kinds of special characters. Local and private network addresses, including Tailscale ones, always open as typed. Timeouts now show the normal error page instead of the encryption warning. The HTTPS upgrade count in your privacy report only counts pages that really loaded securely.

Fixes: If Zalla Unlock ever lapses, locked accents and icons return to the default straight away. A hiccup while checking a purchase no longer takes Unlock away. Locked private tabs are properly hidden from VoiceOver. Cookie banner closing no longer touches ordinary pop-ups. Link cleaning cannot loop. Reset App now resets the search bar width, and Burn It All also forgets which sites you asked for the desktop version of.

## Build 14: Built Around You
- The Flame, since renamed Burn It All: one confirmed tap erases your tabs, history, cookies, and site data, then opens a fresh tab. Free
- HTTPS-Only Mode is now on by default, with a clear warning page and a per-site Continue anyway
- A tidier new tab page: no preloaded shortcuts, a plus tile, and an Add Shortcut list of popular sites, your bookmarks, or any address. Press and hold a link on any page to add it
- Space and Jungle theme packs in Zalla Unlock: accents, icons, backgrounds, and an optional refresh animation that respects Reduce Motion
- Swipe in from the screen edge to go back and forward, with a switch in Settings
- Privacy report for the page you are on and for everything Zalla has done for you, plus optional cookie banner closing that never presses accept
- Friendly pages for no internet, slow sites, and bad certificates
- A How to section in Settings for Quick Action and the other gestures

Improvements: The toolbar blur now stays live over scrolling pages. Swipe down on a page to put the keyboard away, everywhere. Request Desktop Site is remembered per site. Downloads open in a proper preview. Bookmark import understands more Safari and Chrome exports. Zalla can open links from other apps.

Fixes: Fixed the toolbar background looking frozen instead of translucent.

## 1.0: Private by Default
- Free ad and tracker blocker, with an extended tier in Zalla Unlock
- Privacy Shield: encrypted DNS, tracking parameters removed from links, fingerprinting protection, referrer trimming and an optional proxy you set up yourself
- Brave Search is now the default, with Google, Bing, DuckDuckGo, Startpage, Ecosia, Kagi and custom engines. Press and hold the engine chip to switch
- Redesigned Quick Action fan with a separate Menu button
- Zalla Unlock: a one-time purchase for Face ID private tabs, background packs, listen to page, tab groups, per-site CSS, scheduled auto-clear and the extended blocker
- Tip jar, if you want to support development

Improvements: Search bar width slider. Background picker for the new tab page. Short random sayings on new tabs. Swipe down to dismiss the keyboard. Optional city-only local search, stored on your device with no GPS. Tabs you have not used in a while sleep to save memory. New About page.

Fixes: General cleanup and stability work across the app.

## Beta 3: Make It Yours
- Customizable toolbar
- Quick Action toolbar mode, with a search icon and history in the fan
- HTTPS-Only mode
- Quick Setup during onboarding, with a live preview
- Tab restore, so your tabs come back where you left them
- App icons that match your custom accent color

Improvements: Translucent toolbar and address bar. Home logo and widgets slider. Popups now work. Camera and microphone permissions for sites that need them. Page title peek.

## Beta 2: Everyday Polish
- Settings regrouped so things are easier to find
- Share from the Compact toolbar and the Menu
- Lock and Not Secure indicator in the address bar
- Pages reload automatically if they crash
- Privacy and Support links in Settings

Improvements: Better toolbar defaults and tips. Clearer new tab page when empty, and easier shortcuts. Tab spacing and undo after swiping a tab away. Better onboarding defaults. Clearer messages when Reader can't open a page. More download types supported.

Fixes: Removed a black box that showed behind the search bar on some screens. Fixed toolbar background fill in several places.

## Beta 1: First Look
- Address bar at the top or bottom
- Themes and a custom accent color wheel, with hex and gradient options
- An app icon for each accent color
- Swipe to close tabs, plus Close All
- New tab page with quotes or a personal welcome
- Network speed test in Settings

Improvements: Search from the Compact toolbar. Tab switcher polish. Reader mode improvements. Better download detection.

Fixes: The address bar now focuses reliably when tapped.
