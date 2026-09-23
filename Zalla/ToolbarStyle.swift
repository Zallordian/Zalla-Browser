import Foundation

enum ToolbarStyle: String, CaseIterable, Identifiable, Codable {
    case classic = "Classic"
    case compact = "Compact"

    var id: String { rawValue }

    static let storageKey = "toolbarStyle"
}

enum AddressBarPlacement: String, CaseIterable, Identifiable, Codable {
    case bottom = "Bottom"
    case top = "Top"

    var id: String { rawValue }

    static let storageKey = "addressBarPlacement"
}

/// Pure helpers for address chrome title/host display and tap-to-edit prefill.
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
        guard hasPage else { return nil }
        return AddressDisplay.friendlyHost(from: url)
    }

    /// Prefills the Compact editor from the current page URL (empty on a new tab).
    static func editingPrefill(url: URL?) -> String {
        url?.absoluteString ?? ""
    }
}

/// Shared helpers for Safari-like collapsed vs editing address display.
enum AddressDisplay {
    /// Host shown when the address field is unfocused and a page is loaded.
    static func friendlyHost(from url: URL?) -> String? {
        guard var host = url?.host, !host.isEmpty else { return nil }
        if host.lowercased().hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        return host
    }

    /// Collapsed label for classic chrome: friendly host, else placeholder.
    static func collapsedLabel(url: URL?, hasPage: Bool) -> String {
        if hasPage, let host = friendlyHost(from: url) {
            return host
        }
        return "Search or enter a website"
    }

    /// Full URL string used while editing.
    static func editingText(url: URL?) -> String {
        url?.absoluteString ?? ""
    }
}
