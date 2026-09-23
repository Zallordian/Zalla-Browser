import SwiftUI

struct NewTabView: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    var onOpenLibrary: () -> Void

    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage(HomeShortcuts.showRecentHistoryKey) private var showRecentHistory = true
    @AppStorage(HomeShortcuts.washIntensityKey) private var washIntensity = 0.35
    @AppStorage(HomeShortcuts.showLogoKey) private var showLogo = true

    @State private var shortcuts: [HomeShortcut] = HomeShortcuts.load()
    @State private var address = ""
    @State private var isEditing = false
    @State private var editingShortcut: HomeShortcut?
    @FocusState private var searchFocused: Bool

    private var theme: ZallaTheme { ZallaTheme.theme(forRaw: themeID) }

    private var recentChips: [SavedPage] {
        guard showRecentHistory else { return [] }
        return Array(browser.history.prefix(8))
    }

    var body: some View {
        Group {
            if isEditing {
                editModeBody
            } else {
                browseModeBody
            }
        }
        .background {
            Color(uiColor: .systemGroupedBackground)
                .overlay(alignment: .top) {
                    RadialGradient(
                        colors: [theme.primary.opacity(washIntensity), .clear],
                        center: .top,
                        startRadius: 20,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()
        }
        .onAppear { shortcuts = HomeShortcuts.load() }
        .sheet(item: $editingShortcut) { shortcut in
            NavigationStack {
                ShortcutEditor(shortcut: shortcut) { updated in
                    if let index = shortcuts.firstIndex(where: { $0.id == updated.id }) {
                        shortcuts[index] = updated
                    } else {
                        shortcuts.append(updated)
                    }
                    persist()
                    editingShortcut = nil
                } onCancel: {
                    editingShortcut = nil
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var browseModeBody: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                Spacer(minLength: 12)
                if showLogo {
                    Image("ZallaMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityLabel("Zalla")
                }
                searchField
                if !recentChips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentChips) { page in
                                Button { tab.load(page.url) } label: {
                                    Text(page.title)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 14)], spacing: 16) {
                    ForEach(shortcuts) { shortcut in
                        Button {
                            if let url = shortcut.url { tab.load(url) }
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: shortcut.symbolName)
                                    .font(.title2)
                                    .foregroundStyle(theme.primary)
                                    .frame(width: 52, height: 52)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                Text(shortcut.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("View library") { onOpenLibrary() }
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 40)
            }
            .padding(24)
        }
    }

    private var editModeBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit shortcuts")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)

            List {
                ForEach(shortcuts) { shortcut in
                    HStack(spacing: 12) {
                        Image(systemName: shortcut.symbolName)
                            .foregroundStyle(theme.primary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortcut.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(shortcut.url?.host ?? shortcut.urlString)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button {
                            editingShortcut = shortcut
                        } label: {
                            Image(systemName: "pencil.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit \(shortcut.title)")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingShortcut = shortcut }
                }
                .onMove(perform: moveShortcuts)
                .onDelete(perform: deleteShortcuts)

                Button {
                    editingShortcut = HomeShortcut(title: "", urlString: "https://", symbolName: "globe")
                } label: {
                    Label("Add shortcut", systemImage: "plus")
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))

            Text("Drag the handles to rearrange. Swipe or tap Delete to remove.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }

    private var header: some View {
        HStack {
            if tab.isPrivate {
                Label("Private", systemImage: "eye.slash")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            }
            Spacer()
            Button("Edit") {
                withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.top, 12)
    }

    private var searchField: some View {
        TextField("Search or enter a website", text: $address)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.webSearch)
            .submitLabel(.go)
            .focused($searchFocused)
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule(style: .continuous))
            .onSubmit(submitAddress)
            .padding(.horizontal, 8)
    }

    private func moveShortcuts(from source: IndexSet, to destination: Int) {
        shortcuts.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func deleteShortcuts(at offsets: IndexSet) {
        shortcuts.remove(atOffsets: offsets)
        persist()
    }

    private func submitAddress() {
        if let url = AddressResolver.resolve(address, engine: SearchEngine(rawValue: searchEngine) ?? .duckDuckGo) {
            tab.load(url)
            searchFocused = false
        }
    }

    private func persist() {
        HomeShortcuts.save(shortcuts)
    }
}

private struct ShortcutEditor: View {
    @State var shortcut: HomeShortcut
    let onSave: (HomeShortcut) -> Void
    let onCancel: () -> Void

    private var symbols: [String] {
        var list = HomeShortcuts.curatedSymbols
        for extra in ["apple.logo", "chevron.left.forwardslash.chevron.right"] where !list.contains(extra) {
            list.append(extra)
        }
        return list
    }

    var body: some View {
        Form {
            Section("Shortcut") {
                TextField("Title", text: $shortcut.title)
                TextField("URL", text: $shortcut.urlString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            Section("Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            shortcut.symbolName = symbol
                        } label: {
                            Image(systemName: symbol)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(shortcut.symbolName == symbol
                                              ? Color.accentColor.opacity(0.2)
                                              : Color(uiColor: .secondarySystemFill))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(shortcut.title.isEmpty ? "Add shortcut" : "Edit shortcut")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var cleaned = shortcut
                    cleaned.title = cleaned.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    cleaned.urlString = cleaned.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.title.isEmpty { cleaned.title = cleaned.url?.host ?? "Shortcut" }
                    if !cleaned.urlString.lowercased().hasPrefix("http") {
                        cleaned.urlString = "https://" + cleaned.urlString
                    }
                    onSave(cleaned)
                }
                .disabled(shortcut.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
