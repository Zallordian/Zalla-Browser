import Foundation
import UniformTypeIdentifiers

/// Build 52: Settings wording that more than one screen uses, kept in one place so the alert and the footer agree.
enum SettingsCopy {
    /// Shown in the Reset the App confirmation. BrowserStore.resetApp also clears downloads, so this says so.
    static let resetMessage = "Every setting goes back to its default. Your tabs, history, downloads, cookies, and website data are deleted too. Bookmarks are kept."
}

extension BookmarkHTML {
    /// File types the bookmark import picker accepts, in Settings, the Library, and setup.
    /// Bookmark exports are HTML, and some apps save them as plain text.
    static let importTypes: [UTType] = [.html, .text]
}
