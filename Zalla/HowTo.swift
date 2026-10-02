import SwiftUI

/// Short, friendly guides for the gestures and tools that are easy to miss. Collected in Settings.
enum HowToTopic: String, CaseIterable, Identifiable {
    case quickAction
    case historyPeek
    case edgeSwipe
    case pullToRefresh
    case newTabPage
    case addToDashboard
    case flame
    case themeTransitions
    case httpsOnly
    case privacyShield
    case desktopSite
    case findInPage
    case websiteLocation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickAction: return "Quick Action"
        case .historyPeek: return "Peek at history"
        case .edgeSwipe: return "Swipe to go back"
        case .pullToRefresh: return "Pull down to refresh"
        case .newTabPage: return "Your new tab page"
        case .addToDashboard: return "Add to Dashboard"
        case .flame: return "Burn It All"
        case .themeTransitions: return "Theme transitions"
        case .httpsOnly: return "HTTPS-Only Mode"
        case .privacyShield: return "Privacy Shield"
        case .desktopSite: return "Desktop sites"
        case .findInPage: return "Find on a page"
        case .websiteLocation: return "Website location"
        }
    }

    var symbolName: String {
        switch self {
        case .quickAction: return "circle.grid.cross"
        case .historyPeek: return "clock.arrow.circlepath"
        case .edgeSwipe: return "arrow.left.and.right"
        case .pullToRefresh: return "arrow.clockwise"
        case .newTabPage: return "square.grid.2x2"
        case .addToDashboard: return "plus.square.on.square"
        case .flame: return "flame"
        case .themeTransitions: return "sparkles"
        case .httpsOnly: return "lock"
        case .privacyShield: return "shield.lefthalf.filled"
        case .desktopSite: return "desktopcomputer"
        case .findInPage: return "text.magnifyingglass"
        case .websiteLocation: return "location"
        }
    }

    /// One line for the list.
    var summary: String {
        switch self {
        case .quickAction: return "One button, six controls."
        case .historyPeek: return "Hold Back or Forward to see where you were."
        case .edgeSwipe: return "Swipe in from the screen edge."
        case .pullToRefresh: return "Drag a page down to reload it."
        case .newTabPage: return "Shortcuts, backgrounds, and a search bar."
        case .addToDashboard: return "Press and hold any link."
        case .flame: return "Erase everything and close the app."
        case .themeTransitions: return "A leafy sweep or a rocket on refresh."
        case .httpsOnly: return "Secure connections first, a warning otherwise."
        case .privacyShield: return "Cleaner links and fewer clues about you."
        case .desktopSite: return "Ask a site for its big-screen version."
        case .findInPage: return "Jump to a word on the page."
        case .websiteLocation: return "Choose whether sites can ask where you are."
        }
    }

    var steps: [String] {
        switch self {
        case .quickAction:
            return [
                "Tap the center button to fan out Back, Forward, Reload, Tabs, New Tab, and Share.",
                "Tap the search bar on the left, or press and hold the center button, to search or type an address.",
                "Menu sits beside Tabs.",
                "Switch styles any time in Settings, Appearance, Toolbar."
            ]
        case .historyPeek:
            return [
                "Press and hold Back or Forward.",
                "Slide to a page in the list. The new tab page is the last stop going back.",
                "Let go to open it. Slide away from the list to cancel."
            ]
        case .edgeSwipe:
            return [
                "Swipe in from the left edge to go back.",
                "Swipe in from the right edge to go forward.",
                "Swipe back from the first page you opened and you land on your new tab page. Swipe forward to return.",
                "A small arrow follows your finger. Let go past it to turn the page, or let go early to stay put.",
                "If it gets in the way, turn it off in Settings, Browsing."
            ]
        case .pullToRefresh:
            return [
                "Scroll to the top of a page, then pull down and let go.",
                "A little spinner shows while the page reloads and stops when it finishes.",
                "Only a pull from the very top counts, so scrolling around a page never reloads it.",
                "With the keyboard up, pulling down just puts the keyboard away.",
                "To switch it off, open Settings, Browsing."
            ]
        case .newTabPage:
            return [
                "Tap the pencil in the corner to change the background or edit shortcuts.",
                "Tap the plus tile to add a shortcut from a popular list, your bookmarks, or a web address.",
                "In Shortcuts, drag the handles to reorder and swipe to delete.",
                "Logo style in Settings, Home picks the red, white, or black Zalla logo. Auto chooses the one that stands out on your background."
            ]
        case .addToDashboard:
            return [
                "Press and hold a link on any page.",
                "Choose Add to Dashboard.",
                "It shows up on your new tab page."
            ]
        case .flame:
            return [
                "Find Burn It All in the Menu, in Tabs, or add it to your Quick Action buttons in Settings.",
                "Confirm, and Zalla closes every tab and erases history, cookies, and site data.",
                "Flames rise over the page, break apart into embers, and fade to black. Then a plain Clearing browsing data label shows while it finishes, and Zalla closes.",
                "Prefer it quiet? Turn off Burn It All fire effect in Settings, Privacy. With Reduce Motion on, the screen just fades.",
                "Open Zalla again for a clean slate. Bookmarks and downloads stay put."
            ]
        case .themeTransitions:
            return [
                "Jungle sweeps a leafy curtain across the screen. Space sends a rocket up. They play when you refresh and when you apply a theme.",
                "Open Settings, Theme packs. Turn Theme transitions off, or pick Slow, Normal, or Fast.",
                "With Reduce Motion on, you get a quick fade instead.",
                "Theme packs are part of Zalla Unlock."
            ]
        case .httpsOnly:
            return [
                "Zalla tries the secure version of a site first.",
                "If a site has no secure version, you get a warning page first.",
                "Choose Take me back, or Continue anyway for that site only.",
                "Turn it off in Settings, Privacy."
            ]
        case .privacyShield:
            return [
                "Open Settings, Privacy, Privacy Shield.",
                "Pick the protections you want. Each one says what it changes.",
                "Privacy Shield works on this device. It is not a VPN."
            ]
        case .desktopSite:
            return [
                "Open the Menu on a page and choose Request Desktop Site.",
                "Zalla remembers your choice for that site.",
                "Choose it again to go back to the mobile version."
            ]
        case .findInPage:
            return [
                "Open the Menu on a page and choose Find on page.",
                "Type a word. Use the arrows to jump between matches."
            ]
        case .websiteLocation:
            return [
                "Open Settings, Privacy, Website location. Ask is the default. Never blocks every request.",
                "When a site asks, choose Allow or Don't Allow. Zalla remembers your answer for that site.",
                "Your location goes only to the site you allow, never to Zalla. Private tabs ask every time and remember nothing.",
                "To change a saved answer, open Settings, Privacy, Location and swipe the site away."
            ]
        }
    }
}

/// The How to section in Settings.
struct HowToListView: View {
    var body: some View {
        List {
            Section {
                ForEach(HowToTopic.allCases) { topic in
                    NavigationLink {
                        HowToDetailView(topic: topic)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.title)
                                Text(topic.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: topic.symbolName)
                        }
                    }
                }
            } footer: {
                Text("Short guides for the things that are easy to miss.")
            }
        }
        .navigationTitle("How to")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HowToDetailView: View {
    let topic: HowToTopic

    var body: some View {
        List {
            Section {
                ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor, in: Circle())
                            .accessibilityHidden(true)
                        Text(step)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(index + 1): \(step)")
                }
            } header: {
                Text(topic.summary)
                    .textCase(nil)
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
