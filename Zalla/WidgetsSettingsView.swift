import SwiftUI

/// Settings, Tools, Widgets: how to add them, what they show, and a live preview in your accent.
struct WidgetsSettingsView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(WidgetShared.shareKey) private var shareData = WidgetShared.defaultShare
    @AppStorage(SearchFocus.storageKey) private var keyboardReady = SearchFocus.defaultEnabled
    @State private var snapshot = WidgetSnapshot()
    @State private var previewLook = WidgetLookKey.defaultLook

    private var palette: WidgetPalette {
        WidgetPalette(hex: snapshot.accentHex, look: previewLook, isDark: colorScheme == .dark)
    }

    private var emberPalette: WidgetPalette {
        WidgetPalette(hex: snapshot.accentHex, look: .gradient, isDark: colorScheme == .dark)
    }

    var body: some View {
        List {
            Section {
                Toggle("Open search with keyboard ready", isOn: $keyboardReady)
            } footer: {
                Text("Widgets can't take typing on their own, so tapping Search opens Zalla ready to type. This also applies to the Search choice in the app icon menu. Turn it off and Search just opens Zalla.")
            }

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
                Picker("Preview look", selection: $previewLook) {
                    ForEach(WidgetLookKey.allCases, id: \.self) { look in
                        Text(look.title).tag(look)
                    }
                }
                previewSearch
                previewFavorites
                previewBurn
                previewPrivacy
            } header: {
                Text("Preview")
            } footer: {
                Text("Widgets follow your Zalla accent by default. In the widget editor you can pick another color and look, and choose which favorites to show. Burn It All opens its usual confirmation, it never burns on its own.")
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

    private var sampleLinks: [WidgetLink] {
        let own = Array(favoriteLinks.prefix(4))
        if !own.isEmpty { return own }
        return [
            WidgetLink(title: "News", urlString: "https://example.com/1", symbolName: "globe"),
            WidgetLink(title: "Mail", urlString: "https://example.com/2", symbolName: "envelope"),
            WidgetLink(title: "Maps", urlString: "https://example.com/3", symbolName: "map"),
            WidgetLink(title: "Notes", urlString: "https://example.com/4", symbolName: "globe")
        ]
    }

    private var previewSearch: some View {
        VStack(alignment: .leading, spacing: 12) {
            card("Search, small", medium: false, background: WidgetBackdrop(palette: palette)) {
                SearchWidgetView(palette: palette)
            }
            card("Search, medium", medium: true, background: WidgetBackdrop(palette: palette)) {
                SearchWidgetView(palette: palette, medium: true)
            }
        }
        .padding(.vertical, 4)
    }

    private var previewFavorites: some View {
        card("Favorites, medium", medium: true, background: WidgetBackdrop(palette: palette)) {
            FavoritesWidgetView(palette: palette, links: sampleLinks)
        }
        .padding(.vertical, 4)
    }

    private var previewBurn: some View {
        card("Burn It All", medium: false, background: BurnWidgetBackdrop()) {
            BurnWidgetView(palette: emberPalette)
        }
        .padding(.vertical, 4)
    }

    private var previewPrivacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            card("Privacy Report, small", medium: false, background: WidgetBackdrop(palette: palette)) {
                PrivacyWidgetView(palette: palette, counts: snapshot.privacy, hasData: shareData && snapshot.hasData)
            }
            card("Privacy Report, medium", medium: true, background: WidgetBackdrop(palette: palette)) {
                PrivacyWidgetView(palette: palette, counts: snapshot.privacy, hasData: shareData && snapshot.hasData, medium: true)
            }
        }
        .padding(.vertical, 4)
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

    private func card<Content: View, Background: View>(
        _ title: String,
        medium: Bool,
        background: Background,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .padding(16)
                .frame(maxWidth: medium ? CGFloat.infinity : CGFloat(158))
                .frame(height: 158)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) widget preview")
    }
}
