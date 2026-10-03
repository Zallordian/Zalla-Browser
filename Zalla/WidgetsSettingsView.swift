import SwiftUI

/// Settings, Tools, Widgets: how to add them, what they show, and a live preview in your accent.
struct WidgetsSettingsView: View {
    @ObservedObject var browser: BrowserStore
    @AppStorage(WidgetShared.shareKey) private var shareData = WidgetShared.defaultShare
    @State private var snapshot = WidgetSnapshot()

    private var palette: WidgetPalette { WidgetPalette(hex: snapshot.accentHex, soft: false) }
    private var softPalette: WidgetPalette { WidgetPalette(hex: snapshot.accentHex, soft: true) }

    var body: some View {
        List {
            Section {
                Toggle("Share with widgets", isOn: $shareData)
            } footer: {
                Text("Widgets read a small note Zalla keeps on your phone: your accent color, your favorites, and your Privacy Report totals. It never has your history or your open tabs, nothing from a private tab, and widgets never use the network. Turn this off and Zalla erases the note, so widgets show empty.")
            }

            Section("Add a widget") {
                step(1, "Touch and hold an empty spot on your Home Screen or Lock Screen.")
                step(2, "Tap Edit, then Add Widget (the plus button).")
                step(3, "Search for Zalla and pick a widget.")
                step(4, "Touch and hold the widget, then tap Edit Widget to change its color, look, and favorites.")
            }

            Section {
                preview("Search", size: .small, content: AnyView(SearchWidgetView(palette: palette)), background: AnyView(WidgetBackground(palette: palette)))
                preview("Search, medium", size: .medium, content: AnyView(SearchWidgetView(palette: softPalette, medium: true)), background: AnyView(WidgetBackground(palette: softPalette)))
                preview(
                    "Favorites",
                    size: .medium,
                    content: AnyView(FavoritesWidgetView(palette: palette, links: Array(favoriteLinks.prefix(4)))),
                    background: AnyView(WidgetBackground(palette: palette))
                )
                preview("Burn It All", size: .small, content: AnyView(BurnWidgetView(palette: palette)), background: AnyView(BurnWidgetBackground()))
                preview(
                    "Privacy Report",
                    size: .small,
                    content: AnyView(PrivacyWidgetView(palette: palette, counts: snapshot.privacy, hasData: shareData && snapshot.hasData)),
                    background: AnyView(WidgetBackground(palette: palette))
                )
            } header: {
                Text("Preview")
            } footer: {
                Text("Widgets follow your Zalla accent by default. In the widget editor you can pick another color, a softer look, and which favorites to show. Burn It All opens its usual confirmation, it never burns on its own.")
            }
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { snapshot = WidgetSync.preview(bookmarks: browser.bookmarks) }
        .onChange(of: shareData) { _, _ in
            WidgetSync.refresh(bookmarks: browser.bookmarks)
        }
    }

    private var favoriteLinks: [WidgetLink] {
        snapshot.shortcuts.isEmpty ? snapshot.bookmarks : snapshot.shortcuts
    }

    private enum PreviewSize {
        case small, medium
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }

    private func preview(_ title: String, size: PreviewSize, content: AnyView, background: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content
                .padding(16)
                .frame(maxWidth: size == .small ? CGFloat(158) : CGFloat.infinity)
                .frame(height: 158)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) widget preview")
    }
}
