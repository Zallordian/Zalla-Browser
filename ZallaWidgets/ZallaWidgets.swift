import SwiftUI
import WidgetKit

@main
struct ZallaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ZallaSearchWidget()
        ZallaFavoritesWidget()
        ZallaBurnWidget()
        ZallaPrivacyWidget()
    }
}

// MARK: - Search

struct ZallaSearchWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ZallaSearchWidget", intent: ZallaStyleIntent.self, provider: ZallaStyleProvider()) { entry in
            SearchEntryView(entry: entry)
        }
        .configurationDisplayName("Search")
        .description("Search or enter a website in Zalla.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct SearchEntryView: View {
    let entry: ZallaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(WidgetShared.searchLink)
            .containerBackground(for: .widget) {
                switch family {
                case .accessoryCircular, .accessoryRectangular:
                    AccessoryWidgetBackground()
                default:
                    WidgetBackground(palette: entry.palette)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.semibold))
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Zalla")
                        .font(.headline)
                    Text("Search or enter a website")
                        .font(.caption)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        case .systemMedium:
            SearchWidgetView(palette: entry.palette, medium: true)
        default:
            SearchWidgetView(palette: entry.palette)
        }
    }
}

// MARK: - Favorites

struct ZallaFavoritesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ZallaFavoritesWidget", intent: ZallaFavoritesIntent.self, provider: ZallaFavoritesProvider()) { entry in
            FavoritesEntryView(entry: entry)
        }
        .configurationDisplayName("Favorites")
        .description("Open your favorite sites in Zalla with one tap.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct FavoritesEntryView: View {
    let entry: ZallaEntry
    @Environment(\.widgetFamily) private var family

    private var links: [WidgetLink] {
        let count = WidgetShared.favoriteCount(family: family == .systemLarge ? .large : .medium, setting: entry.limit)
        return Array(entry.favorites.prefix(count))
    }

    var body: some View {
        FavoritesWidgetView(
            palette: entry.palette,
            links: links,
            columns: 4,
            showTitles: entry.showTitles,
            interactive: true
        )
        .widgetURL(WidgetShared.appLink)
        .containerBackground(for: .widget) {
            WidgetBackground(palette: entry.palette)
        }
    }
}

// MARK: - Burn It All

struct ZallaBurnWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ZallaBurnWidget", intent: ZallaStyleIntent.self, provider: ZallaStyleProvider()) { entry in
            BurnWidgetView(palette: entry.palette)
                .widgetURL(WidgetShared.burnLink)
                .containerBackground(for: .widget) {
                    BurnWidgetBackground()
                }
        }
        .configurationDisplayName("Burn It All")
        .description("Opens Zalla's Burn It All confirmation. Nothing is erased until you confirm.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Privacy Report

struct ZallaPrivacyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ZallaPrivacyWidget", intent: ZallaStyleIntent.self, provider: ZallaStyleProvider()) { entry in
            PrivacyEntryView(entry: entry)
        }
        .configurationDisplayName("Privacy Report")
        .description("What Zalla has done for you so far: links cleaned, HTTPS upgrades, and cookie banners closed.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct PrivacyEntryView: View {
    let entry: ZallaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(WidgetShared.appLink)
            .containerBackground(for: .widget) {
                switch family {
                case .accessoryRectangular:
                    AccessoryWidgetBackground()
                default:
                    WidgetBackground(palette: entry.palette)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Privacy Report")
                        .font(.headline)
                    if entry.snapshot.hasData {
                        Text("\(entry.snapshot.privacy.total) things Zalla did")
                            .font(.caption)
                    } else {
                        Text("Open Zalla to start")
                            .font(.caption)
                    }
                }
                Spacer(minLength: 0)
            }
        case .systemMedium:
            PrivacyWidgetView(palette: entry.palette, counts: entry.snapshot.privacy, hasData: entry.snapshot.hasData, medium: true)
        default:
            PrivacyWidgetView(palette: entry.palette, counts: entry.snapshot.privacy, hasData: entry.snapshot.hasData)
        }
    }
}
