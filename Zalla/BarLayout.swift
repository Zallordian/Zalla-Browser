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
    /// Build 45: round buttons beside the pill, as tall as the pill, like Safari.
    static let buttonSize: CGFloat = 48
    /// Build 45: Back and Forward together in one capsule, like Safari.
    static let navCapsuleWidth: CGFloat = 92
    /// Even space between every control in the row.
    static let spacing: CGFloat = 8

    /// Build 45: the side inset is the same however many buttons show. 32 points on screens 375 points wide and up,
    /// scaled down on narrower screens, and never under 20.
    static let minimumSideInset: CGFloat = 32
    static let sideInsetFloor: CGFloat = 20
    static let sideInsetReferenceWidth: CGFloat = 375

    static func sideInset(screenWidth: CGFloat) -> CGFloat {
        guard screenWidth > 0, screenWidth < sideInsetReferenceWidth else { return minimumSideInset }
        return max(sideInsetFloor, (minimumSideInset * screenWidth / sideInsetReferenceWidth).rounded())
    }

    /// Build 45: the bar's bottom sits this far above the bottom of the screen, home indicator area included,
    /// like Safari. While collapsed the pill keeps its Build 37 lift above the home indicator.
    static let bottomEdgeGap: CGFloat = 19

    static func bottomInset(collapsed: Bool, homeIndicatorInset: CGFloat) -> CGFloat {
        collapsed ? max(homeIndicatorInset, 0) + ScrollChrome.pillLift : bottomEdgeGap
    }

    /// Width a segment takes in the row.
    static func width(of segment: SafariBarSegment) -> CGFloat {
        switch segment {
        case .nav(let kinds): return kinds.count >= 2 ? navCapsuleWidth : buttonSize
        case .single: return buttonSize
        }
    }

    /// What is left for the pill once the insets, the buttons, and the gaps are taken. The insets never shrink.
    static func pillWidth(screenWidth: CGFloat, segments: [SafariBarSegment]) -> CGFloat {
        let inset = sideInset(screenWidth: screenWidth)
        let buttons = segments.reduce(CGFloat(0)) { $0 + width(of: $1) }
        let gaps = CGFloat(segments.count) * spacing
        return max(screenWidth - inset * 2 - buttons - gaps, 0)
    }

    /// Build 45: neighboring Back and Forward become one capsule; every other button is its own circle.
    static func segments(_ items: [ToolbarItemKind]) -> [SafariBarSegment] {
        var result: [SafariBarSegment] = []
        var hasCapsule = false
        for kind in items {
            let isNav = kind == .back || kind == .forward
            if isNav, case .nav(let kinds)? = result.last {
                result[result.count - 1] = .nav(kinds + [kind])
            } else if isNav, !hasCapsule {
                // Only one capsule per list. A Back or Forward placed apart from the other stays a plain circle.
                hasCapsule = true
                result.append(.nav([kind]))
            } else {
                result.append(.single(kind))
            }
        }
        return result
    }

    /// The Back and Forward capsule for the default layout.
    static func navCapsule(canGoBack: Bool, canGoForward: Bool) -> NavCapsuleState {
        switch (canGoBack, canGoForward) {
        case (true, true): return .both
        case (true, false): return .backOnly
        case (false, true): return .forwardOnly
        case (false, false): return .hidden
        }
    }
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


/// Build 45: one control in the Safari style row. Back and Forward side by side share one capsule.
enum SafariBarSegment: Equatable, Identifiable {
    case nav([ToolbarItemKind])
    case single(ToolbarItemKind)

    /// The capsule keeps one identity as it grows or shrinks, so it resizes in the spring instead of swapping.
    var id: String {
        switch self {
        case .nav: return "nav"
        case .single(let kind): return kind.rawValue
        }
    }
}

enum NavCapsuleState: Equatable {
    case hidden, backOnly, forwardOnly, both

    var width: CGFloat {
        switch self {
        case .hidden: return 0
        case .backOnly, .forwardOnly: return SafariBarMetrics.buttonSize
        case .both: return SafariBarMetrics.navCapsuleWidth
        }
    }
}
