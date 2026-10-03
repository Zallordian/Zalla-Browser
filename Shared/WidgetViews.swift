import SwiftUI

// The looks of the Zalla widgets, shared so the app can preview them in Settings, Widgets and the extension can
// show them on the Home Screen. These views only draw. The extension adds taps (widgetURL and Link) and backgrounds.

/// The colors one widget paints with. `soft` is the quiet look (tinted, not filled).
struct WidgetPalette {
    let accent: Color
    let deep: Color
    let soft: Bool
    private let luma: Double

    init(hex: String, soft: Bool) {
        let value = WidgetShared.rgb(fromHex: hex)
        accent = Color(red: value.red, green: value.green, blue: value.blue)
        deep = Color(red: value.red * 0.72, green: value.green * 0.72, blue: value.blue * 0.72)
        luma = 0.299 * value.red + 0.587 * value.green + 0.114 * value.blue
        self.soft = soft
    }

    /// Text and symbols. Filled looks use white, or near black on a light accent such as yellow.
    var foreground: Color {
        if soft { return accent }
        return luma > 0.62 ? Color.black.opacity(0.85) : Color.white
    }

    var secondary: Color { foreground.opacity(0.78) }
    var tile: Color { soft ? accent.opacity(0.16) : foreground.opacity(0.18) }
}

struct WidgetBackground: View {
    let palette: WidgetPalette

    var body: some View {
        if palette.soft {
            ZStack {
                Color(uiColor: .systemBackground)
                palette.accent.opacity(0.14)
            }
        } else {
            LinearGradient(colors: [palette.accent, palette.deep], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// The dark card behind the Burn It All widget.
struct BurnWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.13, green: 0.10, blue: 0.10), Color(red: 0.05, green: 0.04, blue: 0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Search

struct SearchWidgetView: View {
    let palette: WidgetPalette
    var medium = false

    var body: some View {
        if medium {
            VStack(alignment: .leading, spacing: 12) {
                Text("Zalla")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.secondary)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.semibold))
                    Text("Search or enter a website")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(palette.foreground)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(palette.tile, in: Capsule())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    Circle().fill(palette.tile)
                    Image(systemName: "magnifyingglass")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(palette.foreground)
                }
                .frame(width: 48, height: 48)
                Spacer(minLength: 0)
                Text("Search")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.foreground)
                Text("or enter a website")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Favorites

struct FavoritesWidgetView: View {
    let palette: WidgetPalette
    let links: [WidgetLink]
    var columns = 4
    var showTitles = true
    /// True in the extension, where each tile is a link. The in-app preview draws plain tiles.
    var interactive = false

    private var rows: [[WidgetLink]] {
        guard columns > 0 else { return [] }
        return stride(from: 0, to: links.count, by: columns).map { start in
            Array(links[start..<min(start + columns, links.count)])
        }
    }

    var body: some View {
        if links.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "star")
                    .font(.title2.weight(.semibold))
                Text("No favorites yet")
                    .font(.subheadline.weight(.bold))
                Text("Add shortcuts on Zalla's new tab page.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.secondary)
            }
            .foregroundStyle(palette.foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(row) { link in
                            tile(link)
                        }
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func tile(_ link: WidgetLink) -> some View {
        if interactive, let url = WidgetShared.openLink(for: link.urlString) {
            Link(destination: url) { tileContent(link) }
        } else {
            tileContent(link)
        }
    }

    private func tileContent(_ link: WidgetLink) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.tile)
                Image(systemName: link.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.foreground)
            }
            .frame(height: 46)
            if showTitles {
                Text(link.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.foreground)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Burn It All

struct BurnWidgetView: View {
    let palette: WidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Circle().fill(palette.accent.opacity(0.22))
                Image(systemName: "flame.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 48, height: 48)
            Spacer(minLength: 0)
            Text("Burn It All")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.white)
            Text("Asks you first")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Privacy Report

struct PrivacyWidgetView: View {
    let palette: WidgetPalette
    let counts: WidgetPrivacyCounts
    /// False until the app has written a snapshot (or while sharing is off): a plain call to action shows instead.
    let hasData: Bool
    var medium = false

    var body: some View {
        if !hasData {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 0)
                Text("Privacy Report")
                    .font(.headline.weight(.bold))
                Text("Open Zalla to start your report.")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
            }
            .foregroundStyle(palette.foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if medium {
            VStack(alignment: .leading, spacing: 10) {
                Label("Privacy Report", systemImage: "shield.lefthalf.filled")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.secondary)
                HStack(spacing: 8) {
                    stat(counts.linkCleaned, "Links cleaned")
                    stat(counts.httpsUpgrade, "HTTPS upgrades")
                    stat(counts.cookieBannerDismissed, "Banners closed")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("Privacy Report", systemImage: "shield.lefthalf.filled")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondary)
                Spacer(minLength: 0)
                Text("\(counts.total)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.foreground)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("things Zalla did for you")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(palette.foreground)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(palette.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.tile, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
