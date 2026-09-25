import Foundation

/// One restorable tab. Private tabs are never turned into entries.
struct TabSessionEntry: Codable, Equatable {
    var url: URL
    var title: String
    /// Opaque WKWebView back/forward state (iOS 15+). Optional; the URL is the fallback.
    var interactionState: Data?
}

/// Saved set of normal tabs plus which one was selected.
struct TabSessionSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = TabSessionSnapshot.currentVersion
    var tabs: [TabSessionEntry] = []
    /// Index into `tabs`, or nil when the selected tab was private or blank.
    var selectedIndex: Int?

    var isEmpty: Bool { tabs.isEmpty }
}

/// Pure helpers for saving and restoring open tabs across cold launches.
enum TabSession {
    static let fileName = "session.json"
    static let maxTabs = 50
    /// Larger back/forward blobs are dropped and the tab falls back to its URL.
    static let maxInteractionStateBytes = 512 * 1024

    /// Minimal description of a live tab, so the snapshot logic stays testable without WebKit.
    struct Source {
        var isPrivate: Bool
        var url: URL?
        var title: String
        var isSelected: Bool
        var interactionState: Data?
    }

    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zalla", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func isRestorable(_ url: URL?) -> Bool {
        guard let scheme = url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// Builds a snapshot from live tabs, skipping private tabs and tabs without a web page.
    static func snapshot(from sources: [Source]) -> TabSessionSnapshot {
        var snapshot = TabSessionSnapshot()
        for source in sources where !source.isPrivate {
            guard snapshot.tabs.count < maxTabs, let url = source.url, isRestorable(url) else { continue }
            var state = source.interactionState
            if let data = state, data.count > maxInteractionStateBytes { state = nil }
            let title = source.title.trimmingCharacters(in: .whitespacesAndNewlines)
            snapshot.tabs.append(TabSessionEntry(url: url, title: title.isEmpty ? (url.host ?? url.absoluteString) : title, interactionState: state))
            if source.isSelected { snapshot.selectedIndex = snapshot.tabs.count - 1 }
        }
        return snapshot
    }

    /// Drops anything unsafe to restore and clamps the selection.
    static func sanitized(_ snapshot: TabSessionSnapshot) -> TabSessionSnapshot {
        var result = TabSessionSnapshot()
        result.tabs = Array(snapshot.tabs.filter { isRestorable($0.url) }.prefix(maxTabs))
        if let index = snapshot.selectedIndex, result.tabs.indices.contains(index),
           snapshot.tabs.count == result.tabs.count {
            result.selectedIndex = index
        } else {
            result.selectedIndex = result.tabs.isEmpty ? nil : result.tabs.count - 1
        }
        return result
    }

    static func encode(_ snapshot: TabSessionSnapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    /// Returns nil for unreadable data or a newer format, so a bad file never blocks launch.
    static func decode(_ data: Data) -> TabSessionSnapshot? {
        guard let snapshot = try? JSONDecoder().decode(TabSessionSnapshot.self, from: data),
              snapshot.version <= TabSessionSnapshot.currentVersion else { return nil }
        return sanitized(snapshot)
    }

    /// Writes the snapshot, or removes the file when there is nothing to restore.
    static func save(_ snapshot: TabSessionSnapshot, to url: URL = fileURL) throws {
        if snapshot.isEmpty {
            clear(at: url)
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Readable after first unlock so a prewarmed launch can still restore tabs.
        try encode(snapshot).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func load(from url: URL = fileURL) -> TabSessionSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    static func clear(at url: URL = fileURL) {
        try? FileManager.default.removeItem(at: url)
    }
}
