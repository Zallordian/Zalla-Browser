import Foundation

/// The words Burn It All uses about itself, in one place. Burn It All erases everything and goes back to one fresh
/// tab. It does not quit the app, and none of this copy may say it does. Foundation only, so a test can check it.
enum BurnCopy {
    static let confirmationMessage = "This closes every tab and erases history, cookies, and site data. Then Zalla opens a fresh tab. Bookmarks and downloads stay put."
    static let menuFooter = "Closes every tab, erases history, cookies, and site data, then opens a fresh tab."
    static let accessibilityHint = "Erases tabs, history, cookies, and site data, then opens a fresh tab"
    static let overlayAccessibility = "Clearing browsing data. Zalla will open a fresh tab in a moment."
    static let howToSummary = "Erase everything and start fresh."
    static let safetyDetail = "Erases tabs, history, cookies, and site data in one confirmed tap, then opens a fresh tab. Free."
    static let howToWipeStep = "Confirm, and every tab is closed while history, cookies, and site data are erased."
    static let howToEffectStep = "Flames rise over the page, break apart into embers, and fade to black. Then a plain Clearing browsing data label shows while it finishes, and Zalla opens a fresh tab."
    static let howToAfterStep = "You are left with one fresh tab. Bookmarks and downloads stay put."

    static let all: [String] = [
        confirmationMessage, menuFooter, accessibilityHint, overlayAccessibility,
        howToSummary, safetyDetail, howToWipeStep, howToEffectStep, howToAfterStep
    ]
}
