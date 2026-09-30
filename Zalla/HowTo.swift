import SwiftUI

/// Short, friendly guides for the gestures and tools that are easy to miss. Collected in Settings.
enum HowToTopic: String, CaseIterable, Identifiable {
    case quickAction
    case historyPeek
    case edgeSwipe
    case newTabPage
    case addToDashboard
    case flame
    case httpsOnly
    case privacyShield
    case desktopSite
    case findInPage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickAction: return "Quick Action"
        case .historyPeek: return "Peek at history"
        case .edgeSwipe: return "Swipe to go back"
        case .newTabPage: return "Your new tab page"
        case .addToDashboard: return "Add to Dashboard"
        case .flame: return "Burn It All"
        case .httpsOnly: return "HTTPS-Only Mode"
        case .privacyShield: return "Privacy Shield"
        case .desktopSite: return "Desktop sites"
        case .findInPage: return "Find on a page"
        }
    }

    var symbolName: String {
        switch self {
        case .quickAction: return "circle.grid.cross"
        case .historyPeek: return "clock.arrow.circlepath"
        case .edgeSwipe: return "arrow.left.and.right"
        case .newTabPage: return "square.grid.2x2"
        case .addToDashboard: return "plus.square.on.square"
        case .flame: return "flame"
        case .httpsOnly: return "lock"
        case .privacyShield: return "shield.lefthalf.filled"
        case .desktopSite: return "desktopcomputer"
        case .findInPage: return "text.magnifyingglass"
        }
    }

    /// One line for the list.
    var summary: String {
        switch self {
        case .quickAction: return "One button, six controls."
        case .historyPeek: return "Hold Back or Forward to see where you were."
        case .edgeSwipe: return "Swipe in from the screen edge."
        case .newTabPage: return "Shortcuts, backgrounds, and a search bar."
        case .addToDashboard: return "Press and hold any link."
        case .flame: return "Erase everything and close the app."
        case .httpsOnly: return "Secure connections first, a warning otherwise."
        case .privacyShield: return "Cleaner links and fewer clues about you."
        case .desktopSite: return "Ask a site for its big-screen version."
        case .findInPage: return "Jump to a word on the page."
        }
    }

    var steps: [String] {
        switch self {
        case .quickAction:
            return [
                "Tap the center button to fan out Back, Forward, Reload, Tabs, New Tab, and Share.",
                "Tap the search bar on the left, or press and hold the center button, to search or type an address.",
                "Menu sits beside Tabs.",
                "Switch styles any time in Settings, Toolbar style."
            ]
        case .historyPeek:
            return [
                "Press and hold Back or Forward.",
                "Slide to a page in the list.",
                "Let go to open it. Slide away from the list to cancel."
            ]
        case .edgeSwipe:
            return [
                "Swipe in from the left edge to go back.",
                "Swipe in from the right edge to go forward.",
                "If it gets in the way, turn it off in Settings, Browsing."
            ]
        case .newTabPage:
            return [
                "Tap the pencil in the corner to change the background or edit shortcuts.",
                "Tap the plus tile to add a shortcut from a popular list, your bookmarks, or a web address.",
                "In Shortcuts, drag the handles to reorder and swipe to delete."
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
                "Then Zalla closes. Open it again for a clean slate.",
                "Bookmarks and downloads stay put."
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
