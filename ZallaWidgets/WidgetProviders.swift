import SwiftUI
import WidgetKit

// Every widget reads the same small snapshot the app keeps in the shared App Group (Shared/WidgetSnapshot.swift).
// There is no network call here and no other data source.

struct ZallaEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let accentHex: String
    let soft: Bool
    let source: WidgetFavoritesSource
    let limit: Int
    let showTitles: Bool

    var palette: WidgetPalette { WidgetPalette(hex: accentHex, soft: soft) }

    var favorites: [WidgetLink] {
        source == .bookmarks ? snapshot.bookmarks : snapshot.shortcuts
    }

    static func make(
        accent: WidgetAccentChoice,
        look: WidgetLook,
        source: WidgetFavoritesSource = .shortcuts,
        limit: WidgetFavoriteLimit = .eight,
        showTitles: Bool = true
    ) -> ZallaEntry {
        let snapshot = WidgetShared.load(from: WidgetShared.sharedDefaults())
        return ZallaEntry(
            date: Date(),
            snapshot: snapshot,
            accentHex: WidgetShared.resolvedAccentHex(choiceKey: accent.rawValue, snapshot: snapshot),
            soft: look == .soft,
            source: source,
            limit: limit.value,
            showTitles: showTitles
        )
    }

    /// Shown while the widget gallery loads. Made up, never read from the app.
    static var placeholder: ZallaEntry {
        var snapshot = WidgetSnapshot()
        snapshot.shortcuts = [
            WidgetLink(title: "Favorite", urlString: "https://example.com/1", symbolName: "globe"),
            WidgetLink(title: "Favorite", urlString: "https://example.com/2", symbolName: "book"),
            WidgetLink(title: "Favorite", urlString: "https://example.com/3", symbolName: "newspaper"),
            WidgetLink(title: "Favorite", urlString: "https://example.com/4", symbolName: "star")
        ]
        snapshot.privacy = WidgetPrivacyCounts(linkCleaned: 12, httpsUpgrade: 8, cookieBannerDismissed: 5)
        snapshot.updatedAt = Date()
        return ZallaEntry(
            date: Date(),
            snapshot: snapshot,
            accentHex: WidgetShared.defaultAccentHex,
            soft: false,
            source: .shortcuts,
            limit: 8,
            showTitles: true
        )
    }
}

enum ZallaTimeline {
    /// The app asks for a reload whenever something changes. This is only a safety net.
    static func timeline(_ entry: ZallaEntry) -> Timeline<ZallaEntry> {
        Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(6 * 60 * 60)))
    }
}

struct ZallaStyleProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ZallaEntry { ZallaEntry.placeholder }

    func snapshot(for configuration: ZallaStyleIntent, in context: Context) async -> ZallaEntry {
        context.isPreview ? ZallaEntry.placeholder : ZallaEntry.make(accent: configuration.accent, look: configuration.look)
    }

    func timeline(for configuration: ZallaStyleIntent, in context: Context) async -> Timeline<ZallaEntry> {
        ZallaTimeline.timeline(ZallaEntry.make(accent: configuration.accent, look: configuration.look))
    }
}

struct ZallaFavoritesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ZallaEntry { ZallaEntry.placeholder }

    private func entry(_ configuration: ZallaFavoritesIntent) -> ZallaEntry {
        ZallaEntry.make(
            accent: configuration.accent,
            look: configuration.look,
            source: configuration.source,
            limit: configuration.limit,
            showTitles: configuration.showTitles
        )
    }

    func snapshot(for configuration: ZallaFavoritesIntent, in context: Context) async -> ZallaEntry {
        context.isPreview ? ZallaEntry.placeholder : entry(configuration)
    }

    func timeline(for configuration: ZallaFavoritesIntent, in context: Context) async -> Timeline<ZallaEntry> {
        ZallaTimeline.timeline(entry(configuration))
    }
}
