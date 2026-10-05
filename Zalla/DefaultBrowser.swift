import Foundation

/// Plain wording for the default browser row and the icon quick actions. Foundation only.
/// Zalla can only be picked as the default browser once Apple approves the entitlement for it. Until then the
/// Settings page for Zalla shows no default browser choice, and this copy says so in plain words.
enum DefaultBrowser {
    static let settingsFooter = "This opens Zalla's page in the Settings app. Whether it offers a Default Browser App choice depends on Apple's approval for Zalla, so you may not see one."
    static let quickActionsFooter = "Quick actions are the shortcuts you get by pressing and holding the Zalla icon. When off, they just open Zalla."
}
