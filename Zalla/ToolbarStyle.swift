import CoreGraphics
import Foundation

enum ToolbarStyle: String, CaseIterable, Identifiable, Codable {
    case classic = "Classic"
    case compact = "Compact"
    case quickAction = "Quick Action"

    var id: String { rawValue }

    static let storageKey = "toolbarStyle"

    /// Short description used by onboarding and Settings pickers.
    var summary: String {
        switch self {
        case .classic:
            return "Address bar with Back, Forward, Share, Tabs, and Menu in a full row."
        case .compact:
            return "One floating row with a tap-to-search pill."
        case .quickAction:
            return "A single crimson button that fans out every control when you need it."
        }
    }

    var symbolName: String {
        switch self {
        case .classic: return "dock.rectangle"
        case .compact: return "capsule"
        case .quickAction: return "smallcircle.filled.circle"
        }
    }
}

enum AddressBarPlacement: String, CaseIterable, Identifiable, Codable {
    case bottom = "Bottom"
    case top = "Top"

    var id: String { rawValue }

    static let storageKey = "addressBarPlacement"
}

/// One-time lightweight tips for chrome mode changes and hold-to-reveal.
enum ChromeModeTips {
    static let compactSeenKey = "hasSeenCompactModeTip"
    static let topBarSeenKey = "hasSeenTopBarPlacementTip"
    static let holdRevealSeenKey = "hasSeenHoldRevealTip"
    static let quickActionSeenKey = "hasSeenQuickActionTip"

    static let compactMessage =
        "Compact puts your address and controls in one floating row. Tap the center pill to search or edit the address."

    static let topBarMessage =
        "Your address bar is at the top. In Classic mode, Back, Forward, and tabs stay along the bottom."

    static let quickActionMessage =
        "Quick Action keeps one crimson button at the center of a see-through toolbar. Tap it to reveal Back, Forward, Reload, Tabs, New Tab, Share, and Menu. Tap the search icon on the left, or press and hold the button, to search or enter an address."

    static let holdRevealMessage =
        "Press and hold Back or Forward to peek recent pages that way. Slide to a page, then let go to open it."
}

/// Controls revealed by the Quick Action button, in left-to-right fan order.
enum QuickActionItem: String, CaseIterable, Identifiable {
    case back
    case forward
    case reload
    case tabs
    case newTab
    case share
    case menu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .back: return "Back"
        case .forward: return "Forward"
        case .reload: return "Reload"
        case .tabs: return "Tabs"
        case .newTab: return "New Tab"
        case .share: return "Share"
        case .menu: return "Menu"
        }
    }

    var symbolName: String {
        switch self {
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .reload: return "arrow.clockwise"
        case .tabs: return "square.on.square"
        case .newTab: return "plus"
        case .share: return "square.and.arrow.up"
        case .menu: return "ellipsis"
        }
    }
}

/// Pure layout math for the Quick Action fan.
enum QuickActionLayout {
    /// Wide enough that seven buttons and their labels never touch, narrow enough for a 375pt screen.
    static let radius: Double = 140
    static let startAngle: Double = 165
    static let endAngle: Double = 15

    /// Fan angles in degrees, evenly spread from left (startAngle) to right (endAngle).
    static func angles(count: Int) -> [Double] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [90] }
        let step = (startAngle - endAngle) / Double(count - 1)
        return (0..<count).map { startAngle - Double($0) * step }
    }

    /// Offset from the Quick Action button center for the item at `index`.
    /// Opens upward when the chrome sits at the bottom, downward when it sits at the top.
    static func offset(index: Int, count: Int, placement: AddressBarPlacement, radius: Double = radius) -> CGSize {
        let all = angles(count: count)
        guard all.indices.contains(index) else { return .zero }
        let radians = all[index] * .pi / 180
        let dx = cos(radians) * radius
        let dy = sin(radians) * radius
        return CGSize(width: dx, height: placement == .bottom ? -dy : dy)
    }
}

/// Pure description of what the onboarding mini preview should draw for a chrome combination.
struct ChromePreviewLayout: Equatable {
    var addressAtTop: Bool
    var showsNavRow: Bool
    var navRowAtBottom: Bool
    var showsFloatingRow: Bool
    var showsQuickActionButton: Bool

    static func make(style: ToolbarStyle, placement: AddressBarPlacement) -> ChromePreviewLayout {
        let top = placement == .top
        switch style {
        case .classic:
            return ChromePreviewLayout(
                addressAtTop: top,
                showsNavRow: true,
                navRowAtBottom: true,
                showsFloatingRow: false,
                showsQuickActionButton: false
            )
        case .compact:
            return ChromePreviewLayout(
                addressAtTop: top,
                showsNavRow: false,
                navRowAtBottom: false,
                showsFloatingRow: true,
                showsQuickActionButton: false
            )
        case .quickAction:
            return ChromePreviewLayout(
                addressAtTop: top,
                showsNavRow: false,
                navRowAtBottom: false,
                showsFloatingRow: false,
                showsQuickActionButton: true
            )
        }
    }
}

/// Pure helpers for address chrome title/host display and tap-to-edit prefill.
enum CompactAddressChrome {
    /// Title shown in the Compact pill before the user taps to edit.
    static func pillTitle(hasPage: Bool, pageTitle: String, isReaderActive: Bool) -> String {
        if isReaderActive || hasPage {
            return pageTitle
        }
        return "Search or enter a website"
    }

    /// Secondary host line under the Compact pill title, when a page is loaded.
    static func hostSubtitle(url: URL?, hasPage: Bool) -> String? {
        guard hasPage else { return nil }
        return AddressDisplay.friendlyHost(from: url)
    }

    /// Prefills the Compact editor from the current page URL (empty on a new tab).
    static func editingPrefill(url: URL?) -> String {
        url?.absoluteString ?? ""
    }
}

/// Shared helpers for Safari-like collapsed vs editing address display.
enum AddressDisplay {
    /// Host shown when the address field is unfocused and a page is loaded.
    static func friendlyHost(from url: URL?) -> String? {
        guard var host = url?.host, !host.isEmpty else { return nil }
        if host.lowercased().hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        return host
    }

    /// Collapsed label for classic chrome: friendly host, else placeholder.
    static func collapsedLabel(url: URL?, hasPage: Bool) -> String {
        if hasPage, let host = friendlyHost(from: url) {
            return host
        }
        return "Search or enter a website"
    }

    /// Full URL string used while editing.
    static func editingText(url: URL?) -> String {
        url?.absoluteString ?? ""
    }
}

/// Safari-like connection security for collapsed address chrome.
enum ConnectionSecurity: Equatable {
    case none
    case secure
    case notSecure

    /// Prefer URL scheme; treat HTTPS with mixed content as not secure.
    static func evaluate(url: URL?, hasPage: Bool, hasOnlySecureContent: Bool) -> ConnectionSecurity {
        guard hasPage, let url else { return .none }
        switch url.scheme?.lowercased() {
        case "https":
            return hasOnlySecureContent ? .secure : .notSecure
        case "http":
            return .notSecure
        default:
            return .none
        }
    }

    var accessibilityLabel: String? {
        switch self {
        case .none: return nil
        case .secure: return "Secure connection"
        case .notSecure: return "Not Secure"
        }
    }
}
