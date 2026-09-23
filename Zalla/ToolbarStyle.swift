import Foundation

enum ToolbarStyle: String, CaseIterable, Identifiable, Codable {
    case classic = "Classic"
    case compact = "Compact"

    var id: String { rawValue }

    static let storageKey = "toolbarStyle"
}

/// Pure helpers for Compact chrome title/host display and tap-to-edit prefill.
enum CompactAddressChrome {
    /// Title shown in the Compact pill before the user taps to edit.
    static func pillTitle(hasPage: Bool, pageTitle: String, isReaderActive: Bool) -> String {
        if isReaderActive || hasPage {
            return pageTitle
        }
        return "Search or enter a website"
    }

    /// Secondary host line under the Compact pill title, when a page is loaded.
    static func hostSubtitle(url: URL?, hasPage: Bool) -> String? {
        guard hasPage, let host = url?.host, !host.isEmpty else { return nil }
        return host
    }

    /// Prefills the Compact editor from the current page URL (empty on a new tab).
    static func editingPrefill(url: URL?) -> String {
        url?.absoluteString ?? ""
    }
}
