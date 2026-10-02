import Foundation

/// Light tap when the Settings tab changes. On by default, with a switch in Settings, Appearance.
enum SettingsTabHaptics {
    static let storageKey = "settingsTabHaptics"
    static let defaultEnabled = true

    static func isEnabled(_ stored: Bool?) -> Bool {
        stored ?? defaultEnabled
    }
}

/// Edge fades that hint the Settings tab strip can scroll. Pure numbers, so the rules are easy to test.
enum StripEdgeFade {
    /// Width of each fade, and the distance over which it fades in as the strip scrolls away from an end.
    static let length: CGFloat = 24

    /// True when the tabs are wider than the strip.
    static func canScroll(contentWidth: CGFloat, viewportWidth: CGFloat) -> Bool {
        viewportWidth > 0 && contentWidth > viewportWidth + 0.5
    }

    /// `offset` is how far the strip is scrolled from its left end (0 at rest).
    static func leadingOpacity(offset: CGFloat, contentWidth: CGFloat, viewportWidth: CGFloat) -> Double {
        guard canScroll(contentWidth: contentWidth, viewportWidth: viewportWidth) else { return 0 }
        return clamp(Double(offset / length))
    }

    static func trailingOpacity(offset: CGFloat, contentWidth: CGFloat, viewportWidth: CGFloat) -> Double {
        guard canScroll(contentWidth: contentWidth, viewportWidth: viewportWidth) else { return 0 }
        let remaining = contentWidth - viewportWidth - offset
        return clamp(Double(remaining / length))
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
