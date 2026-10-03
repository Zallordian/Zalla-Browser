import Foundation
import WidgetKit

/// Writes the small snapshot the widgets read (see Shared/WidgetSnapshot.swift). The app is the only writer.
/// What goes in: the accent color, the home shortcuts and bookmarks you already have, and the Privacy Report totals.
/// What never goes in: history, open tabs, anything from a private tab.
@MainActor
enum WidgetSync {
    static func isSharing(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: WidgetShared.shareKey) as? Bool ?? WidgetShared.defaultShare
    }

    /// The accent as hex, matching what the app paints with (a locked theme pack falls back to Zalla Red).
    static func accentHex(in defaults: UserDefaults = .standard) -> String {
        if defaults.bool(forKey: "useCustomAccent") {
            return WidgetShared.normalizedHex(defaults.string(forKey: "customAccentHex") ?? "") ?? WidgetShared.defaultAccentHex
        }
        let id = ZallaThemeID(rawValue: defaults.string(forKey: "themeID") ?? "") ?? .zallaRed
        if id.requiresUnlock, !ZallaUnlockCache.load(from: defaults) { return ZallaThemeID.zallaRed.primaryHex }
        return id.primaryHex
    }

    static func makeSnapshot(bookmarks: [SavedPage], in defaults: UserDefaults = .standard) -> WidgetSnapshot {
        var snapshot = WidgetSnapshot()
        snapshot.accentHex = accentHex(in: defaults)
        snapshot.shortcuts = WidgetShared.links(from: HomeShortcuts.load(from: defaults).map {
            (title: $0.title, urlString: $0.urlString, symbolName: $0.symbolName)
        })
        snapshot.bookmarks = WidgetShared.links(from: bookmarks.map {
            (title: $0.title, urlString: $0.url.absoluteString, symbolName: "bookmark")
        })
        let overall = PrivacyReport.load(from: defaults).overall
        snapshot.privacy = WidgetPrivacyCounts(
            linkCleaned: overall.linkCleaned,
            httpsUpgrade: overall.httpsUpgrade,
            cookieBannerDismissed: overall.cookieBannerDismissed
        )
        return snapshot
    }

    /// The snapshot as it would be written right now, for the in-app previews.
    static func preview(bookmarks: [SavedPage]) -> WidgetSnapshot {
        var snapshot = makeSnapshot(bookmarks: bookmarks)
        snapshot.updatedAt = Date()
        return snapshot
    }

    /// Writes the snapshot and asks the widgets to redraw, only when something changed. Safe to call often.
    static func refresh(bookmarks: [SavedPage]) {
        guard isSharing() else {
            clear()
            return
        }
        let shared = WidgetShared.sharedDefaults()
        let current = WidgetShared.load(from: shared)
        var next = makeSnapshot(bookmarks: bookmarks)
        if current.hasData, next.sameContent(as: current) { return }
        next.updatedAt = Date()
        WidgetShared.save(next, to: shared)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Empties the shared snapshot so the widgets fall back to their empty states.
    static func clear() {
        let shared = WidgetShared.sharedDefaults()
        guard WidgetShared.load(from: shared).hasData else { return }
        WidgetShared.clear(in: shared)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
