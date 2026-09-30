import SwiftUI

/// Add a shortcut to the new tab page: pick a popular site, pick a bookmark, or type an address.
/// The popular list is bundled with Zalla, so nothing is loaded from the network.
struct AddShortcutSheet: View {
    @ObservedObject var browser: BrowserStore
    @Binding var shortcuts: [HomeShortcut]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var matches: [PopularSite] { PopularSites.matching(query) }

    var body: some View {
        NavigationStack {
            List {
                if !isSearching {
                    Section {
                        NavigationLink {
                            BookmarkShortcutList(browser: browser, isAdded: isAdded, onAdd: add)
                        } label: {
                            Label("From your bookmarks", systemImage: "book")
                        }
                        NavigationLink {
                            ManualShortcutForm(onAdd: add)
                        } label: {
                            Label("Type a web address", systemImage: "link")
                        }
                    }
                }
                Section {
                    ForEach(matches) { site in
                        Button {
                            _ = add(title: site.name, urlString: site.urlString, symbolName: site.symbolName)
                        } label: {
                            ShortcutChoiceRow(
                                title: site.name,
                                subtitle: site.domain,
                                symbolName: site.symbolName,
                                added: isAdded(site.urlString)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if matches.isEmpty {
                        Text("Nothing on the list matches. Try typing the web address instead.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Popular sites")
                } footer: {
                    Text("This list is built into Zalla. Nothing is looked up online.")
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search popular sites")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func isAdded(_ urlString: String) -> Bool {
        HomeShortcuts.contains(shortcuts, urlString: urlString)
    }

    /// Adds one shortcut and saves the list. False when the address is unusable, already there, or the list is full.
    private func add(title: String, urlString: String, symbolName: String) -> Bool {
        guard shortcuts.count < HomeShortcuts.maxShortcuts,
              let shortcut = HomeShortcuts.makeShortcut(title: title, urlString: urlString, symbolName: symbolName),
              !HomeShortcuts.contains(shortcuts, urlString: shortcut.urlString) else { return false }
        shortcuts.append(shortcut)
        HomeShortcuts.save(shortcuts)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        return true
    }
}

private struct ShortcutChoiceRow: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let added: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundStyle(added ? Color.green : Color.accentColor)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(added ? "\(title), added" : "Add \(title)")
    }
}

/// Bookmarks Zalla already has, one tap to put them on the new tab page.
private struct BookmarkShortcutList: View {
    @ObservedObject var browser: BrowserStore
    let isAdded: (String) -> Bool
    let onAdd: (String, String, String) -> Bool
    /// Refreshes the checkmarks after each tap.
    @State private var tick = 0

    var body: some View {
        List {
            if browser.bookmarks.isEmpty {
                Text("No bookmarks yet. Bookmark a page and it will show up here.")
                    .foregroundStyle(.secondary)
            }
            ForEach(browser.bookmarks) { page in
                Button {
                    _ = onAdd(page.title, page.url.absoluteString, "globe")
                    tick += 1
                } label: {
                    ShortcutChoiceRow(
                        title: page.title,
                        subtitle: page.url.host ?? page.url.absoluteString,
                        symbolName: "bookmark",
                        added: isAdded(page.url.absoluteString)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .id(tick)
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Type a title and a web address.
private struct ManualShortcutForm: View {
    let onAdd: (String, String, String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var address = ""
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                TextField("Title (optional)", text: $title)
                TextField("Web address", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit(save)
            } footer: {
                if let problem {
                    Text(problem)
                } else {
                    Text("Example: example.com. Zalla adds https for you.")
                }
            }
            Section {
                Button("Add shortcut", action: save)
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Web address")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        guard let normalized = HomeShortcuts.normalizedURLString(address) else {
            problem = "That does not look like a web address. Try something like example.com."
            return
        }
        let host = AddressDisplay.friendlyHost(from: URL(string: normalized)) ?? normalized
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if onAdd(typed.isEmpty ? host : typed, normalized, "globe") {
            dismiss()
        } else {
            problem = "That one is already on your new tab page, or the page is full."
        }
    }
}
