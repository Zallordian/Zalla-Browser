import Foundation

/// Build 42: how the bottom browsing bar is drawn. Safari style is a slim floating bar over the page (Back, Forward,
/// a two line title and domain pill with reload, Tabs, More), like Safari on iOS 26. Classic keeps the Build 41 bars.
/// Foundation only, so the rules can be tested without UIKit.
enum BarLayout: String, CaseIterable, Identifiable {
    case safari = "Safari style"
    case classic = "Classic"

    var id: String { rawValue }

    /// New in Build 42. Nothing was stored under it before, so a missing or unknown value reads as the default.
    static let storageKey = "bottomBarLayout"
    static let defaultLayout: BarLayout = .safari

    var title: String { rawValue }

    static func stored(_ raw: String?) -> BarLayout {
        guard let raw, let layout = BarLayout(rawValue: raw) else { return defaultLayout }
        return layout
    }

    /// Safari style draws the bar only at the bottom, and never replaces the Quick Action bar, which has its own shape.
    static func usesSafariBar(layout: BarLayout, style: ToolbarStyle, placement: AddressBarPlacement) -> Bool {
        layout == .safari && placement == .bottom && style != .quickAction
    }

    /// The button list the toolbar editor changes. Safari style uses the Compact list, which holds the pill's place.
    static func editTarget(layout: BarLayout, style: ToolbarStyle, placement: AddressBarPlacement) -> ToolbarEditTarget {
        usesSafariBar(layout: layout, style: style, placement: placement) ? .compact : .forStyle(style)
    }

    static let settingsFooter = "Safari style is a slim bar that floats over the page, with Back, Forward, the page title, Tabs, and More. Classic keeps the Toolbar Style you pick below. Customize Toolbar changes the Safari style buttons too."
}

/// Sizes for the Safari style bar, kept in one place so the layout never measures itself while scrolling.
enum SafariBarMetrics {
    /// Height of the pill and the round buttons.
    static let height: CGFloat = 48
    /// Pill height while the bar is collapsed to the domain.
    static let collapsedHeight: CGFloat = 36
    /// Round buttons beside the pill.
    static let buttonSize: CGFloat = 44
    /// Space from the screen edges.
    static let edgeMargin: CGFloat = 10
    /// Even space between every control in the row.
    static let spacing: CGFloat = 6
    /// Gap above the home indicator while expanded.
    static let bottomGap: CGFloat = 2
    /// Opacity of a button that cannot be used right now, like Forward with nothing to go forward to.
    static let disabledOpacity: Double = 0.3
    /// Height of the loading line drawn inside the pill. Drawn as an overlay so loading never moves the bar.
    static let progressHeight: CGFloat = 2

    /// The spring every Safari style bar change uses: collapse, expand, editing, and buttons sliding in or out.
    static let springResponse: Double = 0.34
    static let springDamping: Double = 0.86

    /// Build 43: scale a Back or Forward button grows from as it comes back, and shrinks to as it leaves.
    static let hiddenButtonScale: CGFloat = 0.6

    /// Build 43, like Safari: Back is left out when there is nothing to go back to, and Forward when there is
    /// nothing to go forward to. Every other button keeps its place.
    static func visibleItems(_ items: [ToolbarItemKind], canGoBack: Bool, canGoForward: Bool) -> [ToolbarItemKind] {
        items.filter { kind in
            switch kind {
            case .back: return canGoBack
            case .forward: return canGoForward
            default: return true
            }
        }
    }

    static func opacity(enabled: Bool) -> Double {
        enabled ? 1 : disabledOpacity
    }
}
