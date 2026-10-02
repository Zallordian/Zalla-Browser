import Foundation

/// Pure numbers and rules for the immersive layout (Build 22): the page runs edge to edge under a
/// transparent status bar and to the bottom edge, and the bars float over it as glass capsules.
/// Everything here is Foundation only so the rules can be tested without UIKit.
enum ImmersiveLayout {
    /// Same key as the Settings toggle, "Immersive layout".
    static let storageKey = "immersiveLayout"
    /// New installs and upgrades start with the immersive layout on.
    static let defaultEnabled = true

    /// Slim gap between a floating bottom capsule and the physical screen edge.
    static let bottomGap: CGFloat = 12
    /// Gap between the status bar and a floating top capsule.
    static let topGap: CGFloat = 4
    /// Side margin that insets the capsule from the screen edges.
    static let sideMargin: CGFloat = 8
    /// Corner radius for the capsule. A single row bar clamps this to a full capsule.
    static let cornerRadius: CGFloat = 30
    /// How far the solid (non immersive) bottom bar is pulled down into the home indicator area.
    /// The indicator sits about 8 to 13 points above the bottom edge, so 10 keeps clear of it.
    static let solidBottomPullDown: CGFloat = 10
    /// Safe area bottom values above this are the keyboard, not the home indicator.
    static let maxHomeIndicatorInset: CGFloat = 60

    static func isEnabled(_ stored: Bool?) -> Bool {
        stored ?? defaultEnabled
    }

    static func isEnabled(in defaults: UserDefaults) -> Bool {
        isEnabled(defaults.object(forKey: storageKey) as? Bool)
    }

    /// The extra bottom inset content needs so its last line clears the bar.
    /// `barHeight` is the measured chrome height, including the gap under a floating capsule.
    /// The system already adds the home indicator inset to a full bleed page, and a floating capsule
    /// sits inside that inset, so it is subtracted in the immersive layout to avoid a dead strip.
    static func bottomContentInset(barHeight: CGFloat, homeIndicatorInset: CGFloat, immersive: Bool) -> CGFloat {
        let bar = max(barHeight, 0)
        guard immersive else { return bar }
        return max(bar - max(homeIndicatorInset, 0), 0)
    }

    /// Keeps the remembered home indicator inset free of keyboard sized values.
    /// Returns nil when the reading should be ignored.
    static func homeIndicatorInset(fromSafeAreaBottom value: CGFloat) -> CGFloat? {
        guard value >= 0, value <= maxHomeIndicatorInset else { return nil }
        return value
    }
}
