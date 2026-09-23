# Zalla Browser — Project Handoff

**Prepared:** September 21, 2026  
**Purpose:** Portable project context for starting a new ChatGPT Project without losing the decisions, direction, or ideas developed so far.

> **Important provenance note:** The “Conversation Record” section contains the project-conversation content that is visible in the current project context. Some earlier assistant replies are not available here verbatim. Rather than inventing a transcript, the rest of this document captures the conclusions, decisions, and project knowledge that can be reliably inferred from those conversations.

---

## 1. Project at a Glance

**Product name:** Zalla  
**Product type:** Privacy-conscious, highly customizable mobile web browser, initially focused on iPhone/iOS.  
**Core product principle:** Deliver a premium, innovative browser experience while keeping the product as local-to-device as practical and avoiding a large cloud/backend footprint at launch.  
**Brand direction:** Modern, polished, privacy-forward, approachable, and distinctive rather than overtly technical.  
**Primary visual inspiration:** Proton’s polished privacy-app aesthetic, but with **red** as Zalla’s signature color instead of Proton’s purple.  
**Current leading slogan:** **Built around you.**

### Guiding product philosophy

Zalla should feel powerful without feeling complicated. The user should be able to substantially change the browser’s appearance and behavior, but the settings experience should remain curated, visual, and understandable rather than presenting an intimidating wall of toggles.

The first release should favor features that can run locally on the device. Cloud accounts, synchronization systems, remote processing, and other backend-heavy capabilities can be deferred until the product has traction and the value of maintaining infrastructure is clear.

---

## 2. Locked Decisions

### Name

**Zalla** is the selected browser name moving forward.

The naming exploration emphasized:
- Animals
- Space
- Oceans
- Privacy
- Greek and Latin-inspired words
- Short, distinctive, easily brandable names

Earlier strong candidates included **Thalor**, **Zephyr**, and **Zephyrus**, but Zephyr/Zephyrus were rejected because the names were already in use by browsers or browser-related products. Zalla emerged as the preferred name.

### Slogan

**Built around you.**

This was selected because it naturally supports the project’s strongest differentiator: deep personalization and customization without making the product feel cumbersome.

### Launch architecture

The initial product should be designed to operate **primarily or entirely on-device**, wherever possible.

Goals:
- Avoid a massive backend at launch.
- Minimize infrastructure cost and operational overhead.
- Avoid requiring user accounts for core functionality.
- Keep privacy-sensitive data on the user’s device.
- Prefer native platform capabilities over custom cloud systems.
- Add backend-dependent capabilities later only when they create clear user value.

---

## 3. Brand & Visual Design Direction

### Inspiration

The product’s visual direction is inspired by the design language of Proton’s privacy apps: premium dark surfaces, luminous gradients, soft dimensionality, clean typography, rounded geometry, and strong privacy-tech polish.

Zalla should **not** simply copy Proton. The intent is to translate the qualities that make the style appealing into a distinct Zalla identity.

### Zalla signature color

Where Proton often anchors its identity in purple, Zalla should anchor its identity in **red**.

Recommended direction:
- Deep near-black or charcoal surfaces in dark mode.
- A family of rich crimson, ruby, scarlet, and warm red accents.
- Strategic red-to-magenta or red-to-coral gradients for dimensionality.
- Soft glows instead of harsh neon effects.
- Lighter neutral surfaces in light mode with restrained red accents.
- High contrast for browser chrome and security-critical information.

### Suggested working palette

These are practical starting values for design exploration rather than rigid brand standards:

| Role | Suggested color |
|---|---|
| Primary red | `#E33B4F` |
| Bright accent | `#FF5266` |
| Deep crimson | `#A91F36` |
| Dark red | `#741728` |
| Warm coral highlight | `#FF6B63` |
| Red-magenta endpoint | `#D83B72` |
| Dark background | `#111116` |
| Raised dark surface | `#1A1A22` |
| Secondary dark surface | `#24242E` |
| Primary light text | `#F7F7FA` |
| Secondary light text | `#B9B9C4` |
| Light background | `#F7F7FA` |
| Light raised surface | `#FFFFFF` |
| Dark text | `#17171D` |

### Suggested gradients

**Primary brand gradient**  
`linear-gradient(135deg, #E33B4F 0%, #D83B72 100%)`

**Warm action gradient**  
`linear-gradient(135deg, #FF5266 0%, #FF6B63 100%)`

**Deep red gradient**  
`linear-gradient(135deg, #A91F36 0%, #741728 100%)`

**Ambient dark glow concept**  
Use a subtle radial red glow behind elevated cards or hero surfaces, with low opacity and large blur radius.

### UI character

- Generous rounded corners.
- Soft elevation and translucent layers where appropriate.
- Clean, modern sans-serif typography.
- Simple iconography with consistent stroke weight.
- Spacious layouts and controlled density.
- Motion should be subtle and responsive rather than decorative.
- Customization previews should be visual and immediate.

---

## 4. Product Positioning

Zalla’s strongest emerging positioning is:

> **A mobile browser that is private by design, useful offline/local by default, and unusually personal without becoming complicated.**

The browser should not try to win by reproducing every feature of desktop Chrome or by creating a huge services ecosystem on day one. Instead, it can differentiate by making common mobile browsing tasks smoother, more private, and more customizable.

Potential brand themes:
- The browser conforms to the user, not the other way around.
- Powerful personalization with sane defaults.
- Useful tools built directly into browsing workflows.
- Privacy without sacrificing beauty or convenience.
- Local-first features that feel fast and dependable.

---

## 5. Feature Strategy — Local-First Launch

The initial feature set should favor capabilities that can be implemented on-device or through native iOS frameworks.

### Strong local-first feature categories

**Browsing essentials**
- Tabs
- Private tabs
- Favorites/bookmarks
- History
- Downloads
- Find on page
- Reader-style viewing where feasible
- Share sheet integration
- Default search-engine selection
- Per-site controls

**Privacy controls**
- Content/tracker blocking where supported by the browser architecture
- Cookie/site-data clearing controls
- Per-site permission management
- Private browsing
- Optional automatic cleanup behaviors
- Privacy indicators presented in a user-friendly way

**Quality-of-life tools**
- Page translation through supported local/system integrations where possible
- QR code generation and scanning workflows
- Copy clean link / strip common tracking parameters
- Share-page utilities
- Download organization
- Image conversion and export tools
- Page appearance controls

**Customization**
- Theme system
- Accent colors
- Toolbar location/layout choices
- Start-page modules
- Backgrounds/wallpapers
- Search bar styling
- Tab presentation
- Icon choices or app icon variants if platform policy allows
- Adjustable density/spacing presets
- Gesture preferences

---

## 6. Personalization & Customization Philosophy

The browser should be **extremely customizable without looking like it has a million settings**.

### Design principle: Progressive customization

Instead of exposing every setting in a giant list, group customization around what the user is trying to change.

Recommended top-level experience:

**Appearance**  
Theme, colors, wallpapers, contrast, browser chrome style.

**Layout**  
Toolbar placement, controls shown, tab style, compact/comfortable spacing.

**Start Page**  
Modules, ordering, favorites, backgrounds, quick actions.

**Browsing**  
Gestures, link behavior, new-tab behavior, reader preferences.

**Privacy**  
Blocking, cleanup, site data, private mode preferences.

### Presets + advanced controls

Provide attractive presets for users who do not want to tune every detail, while allowing deeper adjustment behind each category.

Examples:
- Minimal
- Focused
- Classic
- Edge-to-edge
- One-handed
- Privacy-first

A user should be able to choose a preset and be finished, or open that preset and customize individual components.

### Live preview

Whenever possible, customization should use a visual preview rather than abstract setting names. The user should be able to understand the effect before applying it.

---

## 7. Password Management Direction

The project discussed whether Zalla should store passwords itself or recommend/integrate existing password managers.

### Preferred launch approach

Do **not** build a proprietary cloud password manager for the first release.

Instead:
- Rely on iOS/system credential and AutoFill capabilities.
- Interoperate cleanly with Apple Passwords/iCloud Keychain and third-party password managers supported by the operating system.
- Make password-manager use easy and unsurprising inside Zalla.

### Why this direction fits the project

A full password manager introduces substantial security responsibility: credential encryption, key management, breach-resistant architecture, sync, recovery, audits, and long-term maintenance. A local-only password vault is technically possible, but it still creates significant security and UX obligations.

For the initial product, leveraging the operating system’s credential infrastructure provides users with strong password functionality while keeping Zalla’s backend requirements low.

A proprietary password vault could be evaluated later if it becomes strategically important.

---

## 8. Built-In Image / Media Conversion

One of the strongest differentiated utility concepts discussed is a browser-native **Export As** workflow.

### Core image workflow

When a user long-presses an image:

**Save Image**  
Save the original format.

**Export As…**  
Convert locally into another image format before saving or sharing.

Potential formats:
- PNG
- JPEG/JPG
- HEIC/HEIF
- WebP
- Possibly PDF for certain workflows

Potential controls:
- Image quality slider for lossy formats
- Preserve/remove metadata
- Resize dimensions
- Preserve transparency when supported
- Save to Photos
- Save to Files
- Copy converted image
- Share converted image

### Why it is compelling

Users frequently encounter WebP and other formats that are inconvenient in downstream workflows. Bringing conversion directly into the long-press/save flow removes the need for a separate converter app or website.

### Video conversion

Video conversion is more resource-intensive and can introduce compatibility, battery, thermal, storage, and legal/DRM considerations. If implemented, it should focus on media the browser is legitimately able to access and process, with a small set of common output options rather than attempting to become a full transcoding suite.

Image conversion is the stronger first version of this concept.

---

## 9. Innovative Feature Ideas That Fit the Local-First Goal

These concepts build on the same philosophy as **Export As**: solve irritating mobile browsing problems directly inside the browser without needing a large server platform.

### Clean Link

A share/copy action that removes common tracking parameters from URLs before copying or sharing them.

Possible actions:
- Copy Clean Link
- Share Clean Link
- Preview what was removed

### Universal Save / Export Sheet

A consistent Zalla sheet for downloadable content:
- Save original
- Rename
- Choose destination
- Convert when supported
- Remove metadata
- Share instead of save

This can make the browser feel unusually polished and intentional.

### Image Metadata Control

Before sharing or exporting an image, optionally remove EXIF/location metadata locally.

### Quick Screenshot Tools

Potential actions:
- Capture visible area
- Capture full page where technically supported
- Copy screenshot
- Save as image/PDF
- Basic crop before export

### Temporary Tabs

A lightweight tab mode for links the user wants to inspect without adding long-term history or clutter. A temporary tab could disappear automatically when closed and optionally avoid persistent history.

### Tab Cleanup Assistant

All local logic:
- Identify duplicate tabs
- Group tabs by domain
- Surface tabs not viewed recently
- Close all except pinned/favorite tabs

This should be deterministic and transparent rather than pretending to require “AI.”

### Per-Site Appearance Memory

Remember local appearance choices per website:
- Reader preference
- Zoom level
- Darkening/theme behavior
- Desktop/mobile request

### Paste & Go / Paste & Search Enhancements

Detect whether clipboard content is a URL, search query, address, tracking number, or other useful pattern and provide contextual actions locally.

### Private Clipboard Options

For sensitive copied content, provide an optional action to clear the clipboard after a user-selected interval, within what iOS permits.

### QR Utility Layer

From any page or selected link:
- Generate QR code
- Scan QR code
- Copy decoded value
- Open decoded link

### Download Intelligence Without a Cloud

Locally categorize downloaded files by type and source domain, provide sensible renaming, detect duplicates, and expose recent downloads cleanly.

### Page Toolkit

A single compact menu that can expose useful actions without bloating the main toolbar:
- Find on page
- Translate
- Reader view
- Text size
- Request desktop site
- Print / save PDF
- Clean link
- QR code
- Page info

### Session Snapshots

Let users save the current collection of tabs as a named local session, e.g. “Trip Planning,” “Research,” or “Shopping,” without requiring cloud sync.

### Focus Profiles

Locally saved browser configurations that change several preferences at once. Examples:
- Work
- Personal
- Minimal
- Private
- Travel

Profiles could control start page, theme, allowed modules, default privacy behavior, and tab presentation without requiring separate accounts.

---

## 10. Features to Defer Because They Push Toward a Large Backend

Unless a native platform service can provide them with minimal infrastructure, defer:

- Proprietary cross-device account synchronization
- Custom cloud bookmark/history/tab sync
- Cloud-hosted password manager
- Server-side AI assistant infrastructure
- Remote image/video conversion farm
- Proprietary VPN service
- Email relay infrastructure
- Large-scale user analytics pipelines
- Social/community systems
- Cloud backup of complete browser state
- Server-side personalization profiles

This does not mean Zalla can never offer these features. The goal is to avoid making them prerequisites for a strong first product.

---

## 11. Suggested Product Principles for Future Decisions

Use these as a filter when evaluating new features:

1. **Does it materially improve mobile browsing?**
2. **Can it run locally or use a native platform service?**
3. **Does it respect user privacy by default?**
4. **Can the UI remain simple even if the capability is powerful?**
5. **Does it reinforce “Built around you”?**
6. **Does it create meaningful differentiation from Safari/Chrome rather than feature-count parity?**
7. **Can it be maintained by a small team without creating disproportionate infrastructure or security obligations?**

---

## 12. Potential MVP Structure

A sensible first milestone could include:

### Browser foundation
- Core browsing experience
- Tabs/private tabs
- History/bookmarks/downloads
- Search engine selection
- Find on page
- Share sheet

### Privacy
- Local privacy controls
- Content blocking where technically available
- Site-data controls
- Clean Link utility

### Personalization
- Zalla red design system
- Light/dark themes
- Accent/theme presets
- Toolbar placement choices
- Start-page customization
- Tab visual options
- Live previews

### Signature utilities
- **Export As** for images
- Metadata stripping for image exports
- QR utilities
- Saved tab sessions
- Tab cleanup / duplicate detection
- Page Toolkit

### Platform integration
- System password/credential AutoFill
- Files/Photos integration
- Native share sheet
- Native text/media frameworks where useful

---

## 13. Open Questions for the Next Project

These are the highest-value questions to answer next:

- What should Zalla’s exact MVP feature list be?
- Will the first release target iPhone only, or iPad at the same time?
- What browser engine/API architecture will be used under current iOS platform rules in target markets?
- What is the minimum supported iOS version?
- What content-blocking capabilities are available with the selected architecture?
- Which customization options belong in v1 versus later releases?
- What should the start page look like?
- What should Zalla’s tab UI look like?
- How should one-handed navigation work?
- Which image formats can be converted most reliably with native frameworks?
- Should Zalla expose “Profiles” in v1 or add them after the base customization system is stable?
- What privacy claims can be made precisely and defensibly based on the final implementation?
- What is the monetization model: paid app, subscription, optional premium upgrade, or another structure?

---

## 14. Recommended Context Prompt for a New ChatGPT Project

Paste the following into the new project’s instructions or first project chat along with this document:

> We are building **Zalla**, a privacy-conscious, highly customizable mobile browser, initially focused on iPhone/iOS. Our guiding principle is to keep the first version as local-to-device as practical so we can avoid a large backend and unnecessary infrastructure cost. Zalla should feel premium and innovative but simple to use. The brand is inspired by the polished visual language of Proton’s privacy apps, but Zalla uses a distinctive red/crimson color identity rather than purple. The selected slogan is **“Built around you.”** Deep personalization is one of the central product differentiators, but settings must remain curated and approachable. We prefer native iOS capabilities and local processing over custom cloud services. One signature feature under consideration is a browser-native **Export As** workflow that lets users long-press web images and locally convert them to formats such as PNG or JPEG before saving or sharing. For passwords, the initial direction is to rely on the operating system’s AutoFill/credential ecosystem rather than building a proprietary cloud password manager. Use the attached Zalla Project Handoff document as the source of truth for decisions and ideas developed so far.

---

# Appendix A — Available Conversation Record

The following is the project conversation content currently visible in context, preserved as closely as possible.

## Conversation: Browser Naming
**Date:** September 21, 2026

**User:**  
“Brower names. I am in the market for some good browser name ideas. I have always been inspired by animals, space, oceans, privacy, etc. Greek and Latin words are also pretty cool to me. Let's lockdown an awesome sounding name, that isn't already a browser, and is easily brandable.”

**User:**  
“Yes, generate more but Thalor is a strong candidate”

**User:**  
“I also like Zephyr a lot and Zephyrus but those are already browsers”

**User:**  
“What about Zalla?”

**User:**  
“I like Zalla. Let's use Zalla moving forward.”

**User:**  
“How about creative / catchy / professional slogans to match”

**User:**  
“Like Built around you.”

**User:**  
“Perfect.”

**Resulting decision:** Zalla is the project/browser name. “Built around you.” is the leading/selected slogan.

---

## Conversation: Browser App Features
**Date:** September 21, 2026

**User:**  
“When it comes to Browser Apps on say iPhones, what are”

**User:**  
“Remove all the features that requires a massive backend. I want to keep the app completely local to the device to reduce overhead and paying for a backend right away.”

**User:**  
“Please do the same thing, but for personalization and customization settings. I would like the browser to be super customizeable, but I don't want it to feel like it's got a million settings, ya know, despite being able to completely alter the look and feel.”

**User:**  
“How do password managers work? Can we store passwords for the user on their end without bogging anything down? And is that a safe bet or should we just incorporate password manager recommendations to eliminate a backend off the back.,”

**User:**  
“How hard would it be to incorporate an inbrowser converter for saving images and perhaps videos.

I noticed a lot of the time ill try and save a photo, and i have to save it as Webmp or something right. What if I could long press and image to save it, Export As, and be able to convert it to a PNG or JPEG, etc.”

**User:**  
“What other innovative features like that could we maybe introduce to the mobile browser world that would bring value to the app without bogging it down and ruining the expeirence”

**Resulting direction:** Favor local-first functionality, deep but curated customization, platform password-manager integration instead of a backend-heavy proprietary vault, browser-native media conversion, and small high-value utilities that remove common mobile browsing friction.

---

## Conversation: Proton Design Style
**Date:** September 21, 2026

**User:**  
“How would you describe the color scheme and design style of Proton Privacy apps?”

**User:**  
“Can you provide the color codes, gradient codes, etc from Proton Privacy. I absolutely love the design style and the colors, and would like to incorporate that into my next project. Give me all the information needed to streamline my next project to match this design style. And then we will reference this chat later on in the process.”

**User:**  
“Perfect. Sounds good. Saying as how Proton focuses on Purple, then the rest of what you said. Can we focus on Red, for this next project.”

**Resulting direction:** Use Proton’s premium privacy-app sensibility as visual inspiration while establishing a distinct Zalla identity centered on red/crimson tones.

---

# Appendix B — Current Project Source of Truth

Unless explicitly changed later, future work should assume:

- The browser is named **Zalla**.
- The slogan is **Built around you.**
- iPhone/iOS is the initial platform focus.
- Zalla is local-first and should avoid a large backend in its initial release.
- Privacy and customization are central values.
- Customization should be deep but presented simply.
- The visual system should be premium, privacy-tech inspired, and centered on red.
- Native/system password management is preferred over building a proprietary password backend at launch.
- Image **Export As** / local conversion is a signature feature candidate.
- Innovative features should solve real mobile browsing friction without adding clutter or heavy infrastructure.
