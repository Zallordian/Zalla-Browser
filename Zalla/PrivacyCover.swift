import Foundation

/// Build 40: the plain Zalla screen that covers the page when Zalla goes to the background, so the app switcher and
/// anyone glancing at it do not see what you were reading. On by default, with a switch in Settings, Privacy.
enum PrivacyCover {
    static let storageKey = "privacyCoverInBackground"
    static let defaultEnabled = true
    static let title = "Hide page in app switcher"

    static func enabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? defaultEnabled
    }

    /// The cover appears only once Zalla is really in the background. Brief interruptions such as Control Center,
    /// Notification Center, a purchase sheet, a permission prompt, or Face ID leave the page on screen.
    /// Returning to the foreground always lifts it.
    static func showsCover(enabled: Bool, phase: Phase, current: Bool) -> Bool {
        switch phase {
        case .background: return enabled
        case .active: return false
        case .inactive: return current && enabled
        }
    }

    enum Phase { case active, inactive, background }
}
