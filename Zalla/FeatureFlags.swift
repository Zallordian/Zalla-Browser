import Foundation

/// Features that are built but switched off for a release. Turning one back on is a one line change here.
enum FeatureFlags {
    /// Video Saver (see docs/VIDEO_SAVER.md) is hidden for version 1. Set to true to bring back the Menu row, the
    /// page detection, the Settings switch, and the line in the Zalla Unlock list. The code and tests stay in place.
    static let videoSaverEnabled = false

    /// Build 52: Set as Default Browser only does something once Apple grants the default browser entitlement
    /// (see docs/DEFAULT_BROWSER.md). Until then the Settings row is hidden. Flip to true in the same change that
    /// turns the entitlement on.
    static let defaultBrowserEntitled = false
}
