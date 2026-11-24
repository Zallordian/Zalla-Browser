import Foundation

/// Redesign phase 2: one Layout choice in place of Bar Layout, Toolbar Style, and Address Bar. Each preset is a set
/// of the three stored settings, so storage keys and everything that reads them stay the same.
enum LayoutPreset: String, CaseIterable, Identifiable {
    case safari
    case classic
    case compact
    case quickAction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safari: return "Safari Style"
        case .classic: return "Classic"
        case .compact: return "Compact"
        case .quickAction: return "Quick Action"
        }
    }

    /// One short line under the title.
    var summary: String {
        switch self {
        case .safari: return "One slim bar at the bottom that floats over the page."
        case .classic: return "Address bar plus a row of buttons, like a desktop browser."
        case .compact: return "Your address and buttons in one floating row."
        case .quickAction: return "A center button that fans out your controls."
        }
    }

    var symbolName: String {
        switch self {
        case .safari: return "rectangle.bottomthird.inset.filled"
        case .classic: return ToolbarStyle.classic.symbolName
        case .compact: return ToolbarStyle.compact.symbolName
        case .quickAction: return ToolbarStyle.quickAction.symbolName
        }
    }

    var barLayout: BarLayout { self == .safari ? .safari : .classic }

    var toolbarStyle: ToolbarStyle {
        switch self {
        case .safari, .classic: return .classic
        case .compact: return .compact
        case .quickAction: return .quickAction
        }
    }

    /// The Safari style bar only exists at the bottom, so it has no Top or Bottom choice.
    var supportsTopPlacement: Bool { self != .safari }

    /// The preset the browser is actually drawing for these stored settings. A Safari style Bar Layout with the bar
    /// at the top draws the chosen toolbar style, so it reads as that style, not as Safari style.
    static func current(layout: BarLayout, style: ToolbarStyle, placement: AddressBarPlacement) -> LayoutPreset {
        if BarLayout.usesSafariBar(layout: layout, style: style, placement: placement) { return .safari }
        switch style {
        case .classic: return .classic
        case .compact: return .compact
        case .quickAction: return .quickAction
        }
    }

    /// The three settings to store when this preset is picked. Safari style always goes to the bottom. The others keep
    /// the placement asked for.
    func settings(placement: AddressBarPlacement) -> (layout: BarLayout, style: ToolbarStyle, placement: AddressBarPlacement) {
        (barLayout, toolbarStyle, supportsTopPlacement ? placement : .bottom)
    }

    /// Words for VoiceOver.
    func accessibilityLabel(placement: AddressBarPlacement) -> String {
        supportsTopPlacement ? "\(title) layout, address bar at the \(placement.rawValue.lowercased())" : "\(title) layout"
    }
}
