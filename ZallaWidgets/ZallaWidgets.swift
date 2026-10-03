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

/// The two things every widget view needs from its surroundings: light or dark, and whether the system is tinting it.
private struct WidgetSurroundings {
    let isDark: Bool
    let tinted: Bool

    init(colorScheme: ColorScheme, renderingMode: WidgetRenderingMode) {
        isDark = colorScheme == .dark
        tinted = renderingMode != .fullColor
    }
}

/// The widget background. A tinted Home Screen widget gets none of ours, the system draws its own.
private struct WidgetContainer: View {
    let palette: WidgetPalette

    var body: some View {
        if palette.tinted {
            Color.clear
        } else {
            WidgetBackdrop(palette: palette)
        }
    }
}

// MARK: - Search

struct ZallaSearchWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ZallaSearchWidget", intent: ZallaStyleIntent.self, provider: ZallaStyleProvider()) { entry in
            SearchEntryView(entry: entry)
        }
        .configurationDisplayName("Search")
        .description("Tap to search or enter a website. Zalla opens with the keyboard ready.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct SearchEntryView: View {
    let entry: ZallaEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var palette: WidgetPalette {
        let around = WidgetSurroundings(colorScheme: colorScheme, renderingMode: renderingMode)
        return entry.palette(isDark: around.isDark, tinted: around.tinted)
    }

    var body: some View {
        content
            .widgetURL(WidgetShared.searchLink)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular:
            AccessoryWidgetBackground()
        default:
            WidgetContainer(palette: palette)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.bold))
                .widgetAccentable()
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.bold))
                    .widgetAccentable()
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
            SearchWidgetView(palette: palette, medium: true)
        default:
            SearchWidgetView(palette: palette)
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var palette: WidgetPalette {
        let around = WidgetSurroundings(colorScheme: colorScheme, renderingMode: renderingMode)
        return entry.palette(isDark: around.isDark, tinted: around.tinted)
    }

    private var links: [WidgetLink] {
        let size: WidgetShared.FavoritesFamily = family == .systemLarge ? .large : .medium
        let count = WidgetShared.favoriteCount(family: size, setting: entry.limit)
        return Array(entry.favorites.prefix(count))
    }

    var body: some View {
        FavoritesWidgetView(
            palette: palette,
            links: links,
            columns: 4,
            showTitles: entry.showTitles,
            large: family == .systemLarge,
            interactive: true
        )
        .widgetURL(WidgetShared.appLink)
        .containerBackground(for: .widget) { WidgetContainer(palette: palette) }
    }
}

// MARK: - Burn It All

struct ZallaBurnWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ZallaBurnWidget", intent: ZallaStyleIntent.self, provider: ZallaStyleProvider()) { entry in
            BurnEntryView(entry: entry)
        }
        .configurationDisplayName("Burn It All")
        .description("Opens Zalla's Burn It All confirmation. Nothing is erased until you confirm.")
        .supportedFamilies([.systemSmall])
    }
}

private struct BurnEntryView: View {
    let entry: ZallaEntry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var palette: WidgetPalette {
        let around = WidgetSurroundings(colorScheme: colorScheme, renderingMode: renderingMode)
        return entry.palette(isDark: around.isDark, tinted: around.tinted)
    }

    var body: some View {
        BurnWidgetView(palette: palette)
            .widgetURL(WidgetShared.burnLink)
            .containerBackground(for: .widget) {
                if palette.tinted {
                    Color.clear
                } else {
                    BurnWidgetBackdrop()
                }
            }
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var palette: WidgetPalette {
        let around = WidgetSurroundings(colorScheme: colorScheme, renderingMode: renderingMode)
        return entry.palette(isDark: around.isDark, tinted: around.tinted)
    }

    var body: some View {
        content
            .widgetURL(WidgetShared.appLink)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var background: some View {
        if family == .accessoryRectangular {
            AccessoryWidgetBackground()
        } else {
            WidgetContainer(palette: palette)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3.weight(.bold))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text("Privacy Report")
                        .font(.headline)
                    Text(lockScreenLine)
                        .font(.caption)
                }
                Spacer(minLength: 0)
            }
        case .systemMedium:
            PrivacyWidgetView(palette: palette, counts: entry.snapshot.privacy, hasData: entry.snapshot.hasData, medium: true)
        default:
            PrivacyWidgetView(palette: palette, counts: entry.snapshot.privacy, hasData: entry.snapshot.hasData)
        }
    }

    private var lockScreenLine: String {
        entry.snapshot.hasData ? "\(entry.snapshot.privacy.total) things Zalla did" : "Open Zalla to start"
    }
}
