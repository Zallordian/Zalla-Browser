import Foundation

/// One step in a tab's history, for hold-to-reveal lists and the back and forward buttons.
/// `Item` is whatever the web view uses for its own entries (a WKBackForwardListItem in the app, a plain value in tests).
enum NewTabHistoryEntry<Item> {
    /// The Zalla new tab page.
    case newTab
    /// The web page the tab was on before it stepped back to the new tab page.
    case currentPage
    /// A normal web history entry.
    case web(Item)
}

extension NewTabHistoryEntry: Equatable where Item: Equatable {}

/// Treats the Zalla new tab page as the first entry of a tab's history.
///
/// A tab that starts on the new tab page and then loads a site has the new tab page "behind" the site's first page.
/// WebKit knows nothing about that page, so going back from the first page parks the tab on the new tab page
/// while the web view keeps its pages, and going forward shows the page again. Pure value logic, so it is easy to test.
struct NewTabHistory: Equatable {
    /// The tab began on the new tab page, so that page sits behind the first loaded page.
    var hasNewTabBehind = false
    /// The new tab page is showing now while the web view still holds the pages the tab visited.
    var isParked = false

    enum Step: Equatable {
        /// Let the web view move through its own history.
        case web
        /// Show the new tab page.
        case showNewTab
        /// Show the page the web view still holds.
        case showPage
    }

    /// `pageShown` is true while a web page (not the new tab page) is on screen.
    func canGoBack(webCanGoBack: Bool, pageShown: Bool) -> Bool {
        guard pageShown, !isParked else { return false }
        return webCanGoBack || hasNewTabBehind
    }

    func canGoForward(webCanGoForward: Bool) -> Bool {
        isParked || webCanGoForward
    }

    func backStep(webCanGoBack: Bool, pageShown: Bool) -> Step? {
        guard pageShown, !isParked else { return nil }
        if webCanGoBack { return .web }
        return hasNewTabBehind ? .showNewTab : nil
    }

    func forwardStep(webCanGoForward: Bool) -> Step? {
        if isParked { return .showPage }
        return webCanGoForward ? .web : nil
    }

    /// Entries behind the current one, newest first, at most `limit`. `web` is the web view's back list, newest first.
    func backEntries<Item>(web: [Item], limit: Int, pageShown: Bool) -> [NewTabHistoryEntry<Item>] {
        guard pageShown, !isParked else { return [] }
        var entries = web.map { NewTabHistoryEntry<Item>.web($0) }
        if hasNewTabBehind { entries.append(.newTab) }
        return Array(entries.prefix(max(0, limit)))
    }

    /// Entries ahead of the current one, nearest first, at most `limit`. `web` is the web view's forward list, nearest first.
    func forwardEntries<Item>(web: [Item], limit: Int) -> [NewTabHistoryEntry<Item>] {
        var entries: [NewTabHistoryEntry<Item>] = isParked ? [.currentPage] : []
        entries.append(contentsOf: web.map { NewTabHistoryEntry<Item>.web($0) })
        return Array(entries.prefix(max(0, limit)))
    }
}
