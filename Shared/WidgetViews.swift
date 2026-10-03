import SwiftUI
import WidgetKit

// The looks of the Zalla widgets, shared so the app can preview them in Settings, Widgets and the extension can
// show them on the Home Screen. These views only draw. The extension adds taps (widgetURL and Link) and the
// container background. WidgetKit is imported only for widgetAccentable, which does nothing outside a widget.

// MARK: - Colors

private func shade(_ red: Double, _ green: Double, _ blue: Double, _ factor: Double) -> Color {
    Color(red: red * factor, green: green * factor, blue: blue * factor)
}

private func lift(_ red: Double, _ green: Double, _ blue: Double, _ amount: Double) -> Color {
    Color(red: red + (1 - red) * amount, green: green + (1 - green) * amount, blue: blue + (1 - blue) * amount)
}

/// Every color one widget paints with, for one look. `tinted` is the Home Screen tinted or Lock Screen rendering,
/// where the system recolors everything and only the shapes matter.
struct WidgetPalette {
    private(set) var accent = Color.red
    private(set) var accentSoft = Color.red
    private(set) var top = Color.black
    private(set) var bottom = Color.black
    private(set) var glowA = Color.clear
    private(set) var glowB = Color.clear
    private(set) var foreground = Color.white
    private(set) var secondary = Color.white
    private(set) var surface = Color.white
    private(set) var edgeDark = Color.clear
    private(set) var edgeLight = Color.clear
    private(set) var icon = Color.white
    private(set) var markFill = Color.white
    private(set) var markInk = Color.black
    private(set) var ring: [Color] = [Color.white, Color.white, Color.white]
    private(set) var tinted = false

    init(hex: String, look: WidgetLookKey, isDark: Bool, tinted: Bool = false) {
        let value = WidgetShared.rgb(fromHex: hex)
        let luma = 0.299 * value.red + 0.587 * value.green + 0.114 * value.blue
        accent = Color(red: value.red, green: value.green, blue: value.blue)
        accentSoft = lift(value.red, value.green, value.blue, 0.35)
        self.tinted = tinted
        if tinted {
            applyTinted()
            return
        }
        switch look {
        case .gradient: applyGradient(value, luma: luma)
        case .midnight: applyMidnight()
        case .aurora: applyAurora()
        case .glass: applyGlass(isDark: isDark)
        case .paper: applyPaper(isDark: isDark)
        }
    }

    private mutating func applyTinted() {
        accent = Color.primary
        accentSoft = Color.primary
        foreground = Color.primary
        secondary = Color.primary.opacity(0.7)
        surface = Color.primary.opacity(0.16)
        icon = Color.primary
        markFill = Color.primary.opacity(0.2)
        markInk = Color.primary
        ring = [Color.primary, Color.primary.opacity(0.65), Color.primary.opacity(0.35)]
    }

    private mutating func applyGradient(_ value: (red: Double, green: Double, blue: Double), luma: Double) {
        let lightAccent = luma > 0.62
        let ink = lightAccent ? Color.black.opacity(0.85) : Color.white
        top = lift(value.red, value.green, value.blue, 0.06)
        bottom = shade(value.red, value.green, value.blue, lightAccent ? 0.8 : 0.5)
        glowA = Color.white.opacity(lightAccent ? 0.3 : 0.26)
        glowB = accentSoft.opacity(0.3)
        foreground = ink
        secondary = ink.opacity(0.78)
        surface = ink.opacity(0.16)
        edgeDark = Color.black.opacity(0.22)
        edgeLight = ink.opacity(0.32)
        icon = ink
        markFill = ink.opacity(0.22)
        markInk = ink
        ring = [ink, ink.opacity(0.62), ink.opacity(0.36)]
    }

    private mutating func applyMidnight() {
        top = Color(red: 0.10, green: 0.11, blue: 0.21)
        bottom = Color(red: 0.03, green: 0.03, blue: 0.07)
        glowA = accent.opacity(0.5)
        glowB = accentSoft.opacity(0.14)
        applyDarkInk()
    }

    private mutating func applyAurora() {
        top = Color(red: 0.04, green: 0.11, blue: 0.19)
        bottom = Color(red: 0.09, green: 0.04, blue: 0.19)
        glowA = Color(red: 0.10, green: 0.85, blue: 0.72).opacity(0.36)
        glowB = accent.opacity(0.46)
        applyDarkInk()
    }

    private mutating func applyGlass(isDark: Bool) {
        if isDark {
            top = Color(red: 0.17, green: 0.17, blue: 0.21)
            bottom = Color(red: 0.08, green: 0.08, blue: 0.11)
            glowA = accent.opacity(0.4)
            glowB = accentSoft.opacity(0.12)
            applyDarkInk()
        } else {
            top = Color(red: 0.98, green: 0.98, blue: 1.0)
            bottom = Color(red: 0.86, green: 0.87, blue: 0.93)
            glowA = accent.opacity(0.3)
            glowB = accentSoft.opacity(0.16)
            applyLightInk()
        }
    }

    private mutating func applyPaper(isDark: Bool) {
        if isDark {
            top = Color(red: 0.17, green: 0.155, blue: 0.145)
            bottom = Color(red: 0.11, green: 0.10, blue: 0.095)
            glowA = accent.opacity(0.14)
            applyDarkInk()
            foreground = Color(red: 0.96, green: 0.94, blue: 0.91)
            secondary = foreground.opacity(0.72)
        } else {
            top = Color(red: 0.995, green: 0.985, blue: 0.965)
            bottom = Color(red: 0.94, green: 0.92, blue: 0.89)
            glowA = accent.opacity(0.12)
            applyLightInk()
            foreground = Color(red: 0.16, green: 0.13, blue: 0.12)
            secondary = foreground.opacity(0.68)
        }
    }

    /// Light text on a dark backdrop, with the accent on the marks and rings.
    private mutating func applyDarkInk() {
        foreground = Color.white
        secondary = Color.white.opacity(0.74)
        surface = Color.white.opacity(0.1)
        edgeDark = Color.black.opacity(0.3)
        edgeLight = Color.white.opacity(0.22)
        icon = accentSoft
        markFill = accent
        markInk = Color.white
        ring = [accentSoft, Color.white.opacity(0.7), Color.white.opacity(0.36)]
    }

    /// Dark text on a light backdrop.
    private mutating func applyLightInk() {
        foreground = Color(red: 0.10, green: 0.10, blue: 0.14)
        secondary = foreground.opacity(0.66)
        surface = Color.white.opacity(0.78)
        edgeDark = Color.black.opacity(0.12)
        edgeLight = Color.white.opacity(0.9)
        icon = accent
        markFill = accent
        markInk = Color.white
        ring = [accent, accentSoft, Color.black.opacity(0.22)]
    }
}

// MARK: - Backdrops and the Zalla mark

/// The widget background: a gradient, two soft glows, and a big faint Zalla shield.
struct WidgetBackdrop: View {
    let palette: WidgetPalette

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [palette.glowA, Color.clear], center: .topLeading, startRadius: 0, endRadius: 240)
            RadialGradient(colors: [palette.glowB, Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 210)
            watermark
        }
    }

    private var watermark: some View {
        Image(systemName: "shield.lefthalf.filled")
            .font(.system(size: 170, weight: .bold))
            .foregroundStyle(palette.foreground.opacity(0.05))
            .offset(x: 60, y: 54)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

/// The Burn It All backdrop: charred at the top, glowing embers at the bottom. It does not follow the accent.
struct BurnWidgetBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.03, blue: 0.03), Color(red: 0.28, green: 0.05, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.42, blue: 0.08).opacity(0.6), Color.clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 170
            )
            RadialGradient(
                colors: [Color(red: 0.9, green: 0.12, blue: 0.15).opacity(0.4), Color.clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 150
            )
        }
    }
}

/// The Zalla shield in a rounded badge.
struct WidgetMark: View {
    let palette: WidgetPalette
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(palette.markFill)
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(palette.markInk)
        }
        .frame(width: size, height: size)
        .widgetAccentable(palette.tinted)
        .accessibilityHidden(true)
    }
}

/// A rounded search bar with a soft inner edge.
struct WidgetSearchPill: View {
    let palette: WidgetPalette
    let label: String
    var height: CGFloat = 44
    var showsArrow = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.icon)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.foreground.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if showsArrow {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(palette.markInk)
                    .frame(width: 28, height: 28)
                    .background(palette.markFill, in: Circle())
                    .widgetAccentable(palette.tinted)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, showsArrow ? 8 : 14)
        .frame(height: height)
        .background(palette.surface, in: Capsule())
        .overlay(edge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var edge: some View {
        Capsule().strokeBorder(
            LinearGradient(colors: [palette.edgeDark, palette.edgeLight], startPoint: .top, endPoint: .bottom),
            lineWidth: 1
        )
    }
}

// MARK: - Search

struct SearchWidgetView: View {
    let palette: WidgetPalette
    var medium = false

    var body: some View {
        if medium {
            mediumBody
        } else {
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetMark(palette: palette, size: 38)
            Spacer(minLength: 6)
            Text("Zalla")
                .font(.title3.weight(.heavy))
                .foregroundStyle(palette.foreground)
                .lineLimit(1)
            Text("Private by default")
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 8)
            WidgetSearchPill(palette: palette, label: "Search", height: 38)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                WidgetMark(palette: palette, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Zalla")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(palette.foreground)
                    Text("Private by default")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 8)
            WidgetSearchPill(palette: palette, label: "Search or enter a website", height: 54, showsArrow: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Favorites

private struct TileColors {
    let top: Color
    let bottom: Color

    init(_ r1: Double, _ g1: Double, _ b1: Double, _ r2: Double, _ g2: Double, _ b2: Double) {
        top = Color(red: r1, green: g1, blue: b1)
        bottom = Color(red: r2, green: g2, blue: b2)
    }

    /// Ruby, amber, emerald, azure, indigo, violet, rose, teal.
    static let all: [TileColors] = [
        TileColors(0.93, 0.30, 0.38, 0.70, 0.12, 0.25),
        TileColors(0.98, 0.62, 0.20, 0.88, 0.36, 0.10),
        TileColors(0.22, 0.75, 0.50, 0.08, 0.52, 0.38),
        TileColors(0.25, 0.60, 0.98, 0.15, 0.38, 0.85),
        TileColors(0.52, 0.45, 0.95, 0.35, 0.28, 0.80),
        TileColors(0.75, 0.35, 0.90, 0.52, 0.20, 0.72),
        TileColors(0.98, 0.45, 0.65, 0.80, 0.25, 0.48),
        TileColors(0.30, 0.78, 0.80, 0.12, 0.55, 0.62)
    ]
}

/// One favorite: its saved icon, or its first letter, on a colored rounded square.
struct WidgetSiteTile: View {
    let link: WidgetLink
    let palette: WidgetPalette
    var size: CGFloat = 48

    private var colors: TileColors {
        TileColors.all[WidgetTileRules.colorIndex(for: link.title, count: TileColors.all.count)]
    }

    var body: some View {
        ZStack {
            shape.fill(fill)
            glyph
        }
        .frame(width: size, height: size)
        .overlay(rim)
        .accessibilityHidden(true)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
    }

    private var fill: LinearGradient {
        if palette.tinted {
            return LinearGradient(colors: [palette.surface, palette.surface], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [colors.top, colors.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var rim: some View {
        shape.strokeBorder(Color.white.opacity(palette.tinted ? 0 : 0.28), lineWidth: 1)
    }

    @ViewBuilder
    private var glyph: some View {
        if WidgetTileRules.showsInitial(symbolName: link.symbolName) {
            Text(WidgetTileRules.initial(of: link.title))
                .font(.system(size: size * 0.46, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.tinted ? palette.foreground : Color.white)
        } else {
            Image(systemName: link.symbolName)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(palette.tinted ? palette.foreground : Color.white)
        }
    }
}

struct FavoritesWidgetView: View {
    let palette: WidgetPalette
    let links: [WidgetLink]
    var columns = 4
    var showTitles = true
    /// True in the large widget: bigger tiles and a search bar along the bottom.
    var large = false
    /// True in the extension, where each tile is a link. The in-app preview draws plain tiles.
    var interactive = false

    private var rows: [[WidgetLink]] {
        guard columns > 0 else { return [] }
        return stride(from: 0, to: links.count, by: columns).map { start in
            Array(links[start..<min(start + columns, links.count)])
        }
    }

    private var tileSize: CGFloat { large ? 56 : 50 }

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 14 : 10) {
            header
            if links.isEmpty {
                emptyState
            } else {
                grid
            }
            if large {
                Spacer(minLength: 0)
                searchBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 8) {
            WidgetMark(palette: palette, size: 24)
            Text("Favorites")
                .font(.footnote.weight(.bold))
                .foregroundStyle(palette.secondary)
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nothing pinned yet")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.foreground)
            Text("Add shortcuts on Zalla's new tab page.")
                .font(.caption)
                .foregroundStyle(palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var grid: some View {
        VStack(spacing: large ? 14 : 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row) { link in
                        tile(link)
                    }
                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        let pill = WidgetSearchPill(palette: palette, label: "Search or enter a website", height: 44)
        if interactive, let url = WidgetShared.searchLink {
            Link(destination: url) { pill }
        } else {
            pill
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
        VStack(spacing: 5) {
            WidgetSiteTile(link: link, palette: palette, size: tileSize)
            if showTitles {
                Text(link.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(link.title)
    }
}

// MARK: - Burn It All

struct BurnWidgetView: View {
    let palette: WidgetPalette

    private var flame: LinearGradient {
        if palette.tinted {
            return LinearGradient(colors: [palette.foreground, palette.foreground], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.88, blue: 0.4),
                Color(red: 1.0, green: 0.52, blue: 0.14),
                Color(red: 0.95, green: 0.2, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "flame.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(flame)
                .shadow(color: Color.orange.opacity(palette.tinted ? 0 : 0.7), radius: 12)
                .widgetAccentable(palette.tinted)
                .accessibilityHidden(true)
            Spacer(minLength: 6)
            Text("Burn It All")
                .font(.headline.weight(.heavy))
                .foregroundStyle(palette.tinted ? palette.foreground : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("Asks you first")
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.tinted ? palette.secondary : Color.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Privacy Report

struct WidgetRingView: View {
    let palette: WidgetPalette
    let counts: WidgetPrivacyCounts
    var lineWidth: CGFloat = 7

    private var segments: [WidgetRingRules.Segment] {
        WidgetRingRules.segments([counts.linkCleaned, counts.httpsUpgrade, counts.cookieBannerDismissed])
    }

    var body: some View {
        ZStack {
            Circle().stroke(palette.surface, lineWidth: lineWidth)
            ForEach(segments, id: \.index) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(palette.ring[segment.index], style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .widgetAccentable(palette.tinted)
        .accessibilityHidden(true)
    }
}

struct PrivacyWidgetView: View {
    let palette: WidgetPalette
    let counts: WidgetPrivacyCounts
    /// False until the app has written a snapshot (or while sharing is off): a plain call to action shows instead.
    let hasData: Bool
    var medium = false

    var body: some View {
        if !hasData {
            emptyBody
        } else if medium {
            mediumBody
        } else {
            smallBody
        }
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetMark(palette: palette, size: 38)
            Spacer(minLength: 6)
            Text("Privacy Report")
                .font(.headline.weight(.heavy))
                .foregroundStyle(palette.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("Open Zalla to start your report.")
                .font(.caption)
                .foregroundStyle(palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("Privacy Report")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(2)
                Spacer(minLength: 4)
                WidgetRingView(palette: palette, counts: counts, lineWidth: 6)
                    .frame(width: 40, height: 40)
            }
            Spacer(minLength: 4)
            Text("\(counts.total)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.foreground)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .widgetAccentable(palette.tinted)
            Text(counts.total == 0 ? "Quiet so far" : "things Zalla did for you")
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            ZStack {
                WidgetRingView(palette: palette, counts: counts, lineWidth: 10)
                VStack(spacing: 0) {
                    Text("\(counts.total)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.foreground)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("total")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.secondary)
                }
                .padding(.horizontal, 16)
            }
            .frame(width: 108, height: 108)
            VStack(alignment: .leading, spacing: 8) {
                legend(0, counts.linkCleaned, "Links cleaned")
                legend(1, counts.httpsUpgrade, "HTTPS upgrades")
                legend(2, counts.cookieBannerDismissed, "Banners closed")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func legend(_ index: Int, _ value: Int, _ label: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(palette.ring[index]).frame(width: 9, height: 9)
            Text("\(value)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(palette.foreground)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}
