import SwiftUI

/// Page indicator for the new tab home slider, tinted with the current accent.
struct HomePageDots: View {
    let count: Int
    let selection: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selection ? tint : Color.secondary.opacity(0.35))
                    .frame(width: index == selection ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Home page \(selection + 1) of \(count)")
    }
}

/// Shared card chrome for home widgets. System materials, soft accent edge.
private struct HomeWidgetCard<Content: View>: View {
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground).opacity(0.85),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            }
    }
}

/// Local-only widget: how many tabs are open right now.
struct HomeTabsWidget: View {
    let totalCount: Int
    let privateCount: Int
    let tint: Color
    let onOpenTabs: () -> Void
    let onNewTab: () -> Void

    var body: some View {
        HomeWidgetCard(tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Your tabs", systemImage: "square.on.square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(totalCount)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(totalCount == 1 ? "tab open" : "tabs open")
                            .font(.subheadline.weight(.semibold))
                        if let privateLabel = HomeWidgets.privateTabLabel(privateCount) {
                            Text(privateLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(HomeWidgets.tabCountLabel(totalCount))
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button(action: onOpenTabs) {
                        Text("Show all tabs")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint)
                    Button(action: onNewTab) {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint)
                    .accessibilityLabel("New tab")
                }
            }
        }
    }
}

/// Local-only widget: the last few pages from on-device history.
struct HomeRecentWidget: View {
    let pages: [SavedPage]
    let tint: Color
    let onOpen: (URL) -> Void
    let onOpenLibrary: () -> Void

    var body: some View {
        HomeWidgetCard(tint: tint) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Recently visited", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    Button("History", action: onOpenLibrary)
                        .font(.caption.weight(.semibold))
                }
                ForEach(pages) { page in
                    Button {
                        onOpen(page.url)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(HomeWidgets.displayTitle(for: page))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if let host = AddressDisplay.friendlyHost(from: page.url) {
                                    Text(host)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
