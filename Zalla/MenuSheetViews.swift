import SwiftUI

/// Build 41: the card at the top of the Menu. Only numbers Zalla really counted itself (see PrivacyReport); there is
/// no trackers blocked, data saved, or time saved figure, because Zalla has no honest way to measure those.
struct MenuPrivacyCard: View {
    let counts: PrivacyReport.Counts
    let blockingOn: Bool
    let secure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Privacy at a glance", systemImage: "shield.lefthalf.filled")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .top, spacing: 8) {
                MenuStatTile(value: counts.linkCleaned, label: "Links cleaned")
                MenuStatTile(value: counts.httpsUpgrade, label: "Secure upgrades")
                MenuStatTile(value: counts.cookieBannerDismissed, label: "Cookie banners closed")
            }
            Text(statusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the privacy report")
    }

    private var statusLine: String {
        let blocking = blockingOn ? "Blocking on for this site" : "Blocking off for this site"
        return secure ? blocking + ". Secure connection." : blocking + "."
    }
}

struct MenuStatTile: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted())
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Build 41: My actions, the big square buttons at the top of the Menu. The person picks them in
/// Customize My Actions (stored under the old Menu row key).
struct MenuActionsGrid: View {
    @ObservedObject var tab: BrowserTab
    let items: [MenuTopRowItem]
    let tint: Color
    let onAction: (MenuTopRowItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                MenuActionTile(
                    title: title(for: item),
                    symbol: symbol(for: item),
                    tint: tint,
                    enabled: isEnabled(item)
                ) { onAction(item) }
            }
        }
        .padding(.vertical, 6)
    }

    private func title(for item: MenuTopRowItem) -> String {
        switch item {
        case .reload: return tab.isLoading ? "Stop" : item.shortTitle
        case .reader: return tab.isReaderActive ? "Exit Reader" : item.shortTitle
        default: return item.shortTitle
        }
    }

    private func symbol(for item: MenuTopRowItem) -> String {
        if item == .reload, tab.isLoading { return "xmark" }
        return item.symbolName
    }

    private func isEnabled(_ item: MenuTopRowItem) -> Bool {
        switch item {
        case .back: return tab.canGoBack
        case .forward: return tab.canGoForward
        case .reload, .find, .home, .reader, .privacyReport, .desktopSite: return tab.hasPage
        case .share, .bookmark: return tab.url != nil
        case .tabs, .settings, .newTab, .burn, .downloads, .history, .newPrivateTab: return true
        }
    }
}

struct MenuActionTile: View {
    let title: String
    let symbol: String
    let tint: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill))
                    )
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(title)
    }
}
