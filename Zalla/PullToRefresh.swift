import Foundation

/// Pull down at the top of a web page to reload it. On by default, one switch in Settings, Browsing.
enum PullToRefresh {
    static let storageKey = "pullToRefresh"

    /// The spinner never hangs around longer than this, even if a page never reports that it finished.
    static let giveUpAfter: TimeInterval = 12

    static var isEnabled: Bool { enabled(in: .standard) }

    static func enabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? true
    }

    /// Whether a completed pull should reload. With the keyboard up, a pull down puts the keyboard away instead.
    static func shouldReload(enabled: Bool, keyboardVisible: Bool, hasPage: Bool) -> Bool {
        enabled && hasPage && !keyboardVisible
    }
}
