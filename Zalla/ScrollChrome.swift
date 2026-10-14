import Foundation

/// Build 35, Safari style browsing: the page runs under a transparent status bar, and the bottom toolbar shrinks to a
/// small address pill while you scroll down. Foundation only, so the rules can be tested without UIKit.
enum ScrollChrome {
    /// Settings, Appearance, "Page under the status bar". On by default.
    static let underStatusBarKey = "pageUnderStatusBar"
    static let underStatusBarDefault = true
    /// Settings, Appearance, "Collapse toolbar while scrolling". On by default.
    static let collapseKey = "collapseToolbarOnScroll"
    static let collapseDefault = true

    /// Points the page has to travel in one direction before the bar changes, so small jitters do nothing.
    static let threshold: CGFloat = 24
    /// Within this distance of the top or the bottom of the page the full bar is shown.
    static let edgeSlack: CGFloat = 12
    /// Build 36: the widest the address pill gets while the toolbar is collapsed.
    static let collapsedPillWidth: CGFloat = 220
    /// Build 37: gap between the collapsed pill and the top of the home indicator area, so a tap on the pill never
    /// lands on the system's swipe home zone. Also the lift on devices without a home indicator.
    static let pillLift: CGFloat = 14

    /// Space under the bottom bar group. Expanded it is the Build 22 value (a slim gap in the immersive layout, a small
    /// pull down into the indicator area for solid bars). Collapsed, the pill sits `pillLift` above the home indicator
    /// area: the immersive group runs to the physical edge, so the indicator inset is added; solid bars already sit
    /// above it.
    static func bottomPadding(collapsed: Bool, immersive: Bool, homeIndicatorInset: CGFloat) -> CGFloat {
        let expanded = immersive ? ImmersiveLayout.bottomGap : -ImmersiveLayout.solidBottomPullDown
        guard collapsed else { return expanded }
        return immersive ? max(homeIndicatorInset, 0) + pillLift : pillLift
    }

    /// Pages that scroll less than this never collapse the bar.
    static let minimumScrollRange: CGFloat = 120

    /// The page goes under the status bar only in the immersive layout with the address bar at the bottom, and only
    /// where WebKit can keep a site's fixed header clear of the clock (`supported`). Otherwise the Build 24 strip stays.
    static func pageUnderStatusBar(enabled: Bool, immersive: Bool, bottomBar: Bool, supported: Bool) -> Bool {
        enabled && immersive && bottomBar && supported
    }

    /// The bottom toolbar may collapse only for a loaded page with a bottom Classic or Compact bar, and never while
    /// the address is being edited.
    static func canCollapse(enabled: Bool, bottomBar: Bool, quickAction: Bool, hasPage: Bool, editing: Bool) -> Bool {
        enabled && bottomBar && !quickAction && hasPage && !editing
    }

    /// Where the scrolling stands. `lastDirection` is 1 for moving down the page, -1 for moving up, 0 at rest.
    struct Tracker: Equatable {
        var collapsed = false
        var anchor: CGFloat = 0
        var lastOffset: CGFloat = 0
        var lastDirection = 0
    }

    /// The next state after the page scrolled to `offset` (0 at the top of the page). `maxOffset` is the offset at the
    /// bottom of the page. Moving down by `threshold` collapses, moving up by `threshold` expands, and the top, the
    /// bottom, and short pages always show the full bar.
    static func next(_ tracker: Tracker, offset: CGFloat, maxOffset: CGFloat) -> Tracker {
        var state = tracker
        let delta = offset - state.lastOffset
        let direction = delta > 0 ? 1 : (delta < 0 ? -1 : 0)
        if direction != 0, direction != state.lastDirection {
            state.anchor = state.lastOffset
            state.lastDirection = direction
        }
        state.lastOffset = offset
        let nearTop = offset <= edgeSlack
        let nearBottom = offset >= maxOffset - edgeSlack
        if maxOffset < minimumScrollRange || nearTop || nearBottom {
            state.collapsed = false
            state.anchor = offset
            return state
        }
        if offset - state.anchor >= threshold {
            state.collapsed = true
        } else if state.anchor - offset >= threshold {
            state.collapsed = false
        }
        return state
    }
}
