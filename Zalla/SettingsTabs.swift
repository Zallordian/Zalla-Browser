import SwiftUI

/// The strip of category tabs across the top of Settings. It scrolls sideways when the text is large, shows the
/// selected tab in the accent color with an underline, keeps the selected tab centered, ticks lightly when the tab
/// changes, and fades its edges when there is more to scroll to.
struct SettingsTabStrip: View {
    @Binding var selection: SettingsCategory
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsTabHaptics.storageKey) private var hapticsOn = SettingsTabHaptics.defaultEnabled
    @State private var scrollOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    private static let space = "settingsTabStrip"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(SettingsCategory.allCases) { category in
                        tab(category)
                            .id(category)
                    }
                }
                .padding(.horizontal, 12)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TabStripMetricsKey.self,
                            value: TabStripMetrics(
                                offset: -geo.frame(in: .named(Self.space)).minX,
                                contentWidth: geo.size.width
                            )
                        )
                    }
                }
            }
            .coordinateSpace(name: Self.space)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewportWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, width in viewportWidth = width }
                }
            }
            .onPreferenceChange(TabStripMetricsKey.self) { metrics in
                scrollOffset = metrics.offset
                contentWidth = metrics.contentWidth
            }
            .overlay(alignment: .leading) {
                edgeFade(leading: true)
            }
            .overlay(alignment: .trailing) {
                edgeFade(leading: false)
            }
            .onChange(of: selection) { _, newValue in
                if SettingsTabHaptics.isEnabled(hapticsOn) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings categories")
    }

    /// A soft fade into the background on an edge that has more tabs behind it.
    private func edgeFade(leading: Bool) -> some View {
        let opacity = leading
            ? StripEdgeFade.leadingOpacity(offset: scrollOffset, contentWidth: contentWidth, viewportWidth: viewportWidth)
            : StripEdgeFade.trailingOpacity(offset: scrollOffset, contentWidth: contentWidth, viewportWidth: viewportWidth)
        let background = Color(uiColor: .systemBackground)
        return LinearGradient(
            colors: [background, background.opacity(0)],
            startPoint: leading ? .leading : .trailing,
            endPoint: leading ? .trailing : .leading
        )
        .frame(width: StripEdgeFade.length)
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func tab(_ category: SettingsCategory) -> some View {
        let selected = selection == category
        return Button {
            selection = category
        } label: {
            VStack(spacing: 4) {
                Image(systemName: category.symbolName)
                    .font(.title3)
                    .imageScale(.medium)
                Text(category.title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Capsule()
                    .fill(selected ? accent : Color.clear)
                    .frame(height: 3)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: selected)
            }
            .foregroundStyle(selected ? accent : Color.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .frame(minWidth: 80, minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.title)
        .accessibilityHint("Shows \(category.title) settings")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Where the tab strip is scrolled and how wide its tabs are, for the edge fades.
private struct TabStripMetrics: Equatable {
    var offset: CGFloat = 0
    var contentWidth: CGFloat = 0
}

private struct TabStripMetricsKey: PreferenceKey {
    static var defaultValue = TabStripMetrics()
    static func reduce(value: inout TabStripMetrics, nextValue: () -> TabStripMetrics) {
        value = nextValue()
    }
}
