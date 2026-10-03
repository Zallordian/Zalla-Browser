import Foundation

/// Plain wording for the default browser row and the icon quick actions. Foundation only.
/// Zalla can only be picked as the default browser once Apple approves the entitlement for it. Until then the
/// Settings page for Zalla shows no default browser choice, and this copy says so in plain words.
enum DefaultBrowser {
    static let settingsFooter = "This opens Zalla in the Settings app. A Default Browser App choice appears there only once Apple has approved Zalla for it, so it may not be there yet."
    static let quickActionsFooter = "Quick actions are the shortcuts you get by pressing and holding the Zalla icon. When off, they just open Zalla."
}
