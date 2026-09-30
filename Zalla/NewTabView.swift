import SwiftUI

struct NewTabView: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    var onOpenLibrary: () -> Void
    var onOpenTabs: () -> Void = {}

    @AppStorage(SearchEngine.storageKey) private var searchEngine = SearchEngine.defaultEngine.rawValue
    @AppStorage(SearchEngine.customTemplateKey) private var customSearchTemplate = ""
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"
    @AppStorage(HomeShortcuts.washIntensityKey) private var washIntensity = 0.35
    @AppStorage(HomeShortcuts.showLogoKey) private var showLogo = true
    @AppStorage(HomeWelcomeMode.storageKey) private var welcomeModeRaw = HomeWelcomeMode.quotes.rawValue
    @AppStorage(HomeWelcomeMode.userNameKey) private var userName = ""
    @AppStorage(HomeShortcuts.showSliderKey) private var showSlider = true
    @AppStorage(HomeShortcuts.showRecentHistoryKey) private var showRecentHistory = true
    @AppStorage(HomeShortcuts.hideAddHintKey) private var hideAddHint = false
    @AppStorage(NewTabBackground.storageKey) private var backgroundRaw = NewTabBackground.standard.storageValue
    @AppStorage(NewTabPhotoStore.revisionKey) private var photoRevision = 0
    @ObservedObject private var unlock = ZallaUnlock.shared
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var showBackgroundPicker = false
    @State private var homePage = 0
    @State private var shortcuts: [HomeShortcut] = HomeShortcuts.load()
    @State private var address = ""
    @State private var isEditing = false
    @State private var editingShortcut: HomeShortcut?
    @FocusState private var searchFocused: Bool

    private var theme: ZallaTheme {
        ZallaTheme.resolved(themeID: themeID, useCustom: useCustomAccent, customHex: customAccentHex)
    }

    private var welcomeMode: HomeWelcomeMode {
        HomeWelcomeMode(rawValue: welcomeModeRaw) ?? .quotes
    }

    /// The background actually drawn: packs fall back to the standard look without Zalla Unlock.
    private var background: NewTabBackground {
        _ = photoRevision
        return NewTabBackground(storageValue: backgroundRaw)
            .effective(unlocked: unlock.isUnlocked, hasPhoto: NewTabPhotoStore.exists)
    }

    /// Text on a dark or light background keeps its contrast; the standard look follows the system.
    private var contentColorScheme: ColorScheme {
        guard let dark = background.prefersDarkContent else { return systemColorScheme }
        return dark ? .dark : .light
    }

    var body: some View {
        Group {
            if isEditing {
                editModeBody
            } else {
                browseModeBody
            }
        }
        .environment(\.colorScheme, contentColorScheme)
        .background {
            NewTabBackgroundView(
                background: background,
                theme: theme,
                washIntensity: washIntensity,
                photo: background == .photo ? NewTabPhotoStore.image() : nil
            )
        }
        .onAppear { shortcuts = HomeShortcuts.load() }
        .sheet(isPresented: $showBackgroundPicker) {
            NewTabBackgroundSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
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
                homeHero
                searchField
                if shortcuts.isEmpty {
                    emptyShortcutTile
                } else {
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
                }
                Button("View library") { onOpenLibrary() }
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 40)
            }
            .padding(24)
            .contentShape(Rectangle())
            .onTapGesture { searchFocused = false }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Home slider

    private var sliderPages: [HomeWidgets.Page] {
        HomeWidgets.pages(
            sliderEnabled: showSlider,
            showRecentHistory: showRecentHistory,
            isPrivate: tab.isPrivate,
            hasHistory: !browser.history.isEmpty
        )
    }

    @ViewBuilder
    private var homeHero: some View {
        let pages = sliderPages
        if pages.count <= 1 {
            welcomePage
        } else {
            VStack(spacing: 10) {
                TabView(selection: $homePage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        sliderPage(page)
                            .padding(.horizontal, 4)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 184)
                HomePageDots(count: pages.count, selection: homePage, tint: theme.primary)
            }
            .onChange(of: pages.count) { _, newCount in
                if homePage >= newCount { homePage = 0 }
            }
        }
    }

    @ViewBuilder
    private func sliderPage(_ page: HomeWidgets.Page) -> some View {
        switch page {
        case .welcome:
            welcomePage
        case .tabs:
            HomeTabsWidget(
                totalCount: browser.tabs.count,
                privateCount: browser.tabs.filter(\.isPrivate).count,
                tint: theme.primary,
                onOpenTabs: onOpenTabs,
                onNewTab: { browser.addTab() }
            )
        case .recent:
            HomeRecentWidget(
                pages: HomeWidgets.recentPages(browser.history),
                tint: theme.primary,
                onOpen: { url in tab.load(url) },
                onOpenLibrary: onOpenLibrary
            )
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 18) {
            if showLogo {
                Image("ZallaMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityLabel("Zalla")
            }
            welcomeBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var welcomeBlock: some View {
        switch welcomeMode {
        case .none:
            EmptyView()
        case .name:
            let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                Text("Welcome back")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            } else {
                Text("Welcome, \(trimmed)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        case .quotes:
            Text(tab.newTabSaying)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    /// Fresh installs have no shortcuts: one empty, semi-transparent tile with a plus. The hint can be dismissed,
    /// which leaves just the small tile.
    private var emptyShortcutTile: some View {
        Button {
            editingShortcut = HomeShortcut(title: "", urlString: "https://", symbolName: "globe")
        } label: {
            VStack(spacing: hideAddHint ? 0 : 8) {
                Image(systemName: "plus")
                    .font(hideAddHint ? .title3.weight(.semibold) : .title2.weight(.semibold))
                    .foregroundStyle(theme.primary)
                if !hideAddHint {
                    Text("Add a shortcut")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: hideAddHint ? 52 : 108, height: hideAddHint ? 52 : 92)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground).opacity(0.45),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.primary.opacity(0.25), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if !hideAddHint {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { hideAddHint = true }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 32, minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide the add shortcut hint")
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Add a shortcut")
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
            Button {
                showBackgroundPicker = true
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Change new tab background")
            Menu {
                Button {
                    editingShortcut = HomeShortcut(title: "", urlString: "https://", symbolName: "globe")
                } label: {
                    Label("Add shortcut", systemImage: "plus")
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
                } label: {
                    Label("Edit shortcuts", systemImage: "pencil")
                }
            } label: {
                Text("Shortcuts")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityLabel("Shortcuts menu")
        }
        .padding(.top, 12)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.isPrivate ? "eye.slash" : "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search or enter a website", text: $address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .focused($searchFocused)
            SearchEngineChip(theme: theme)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule(style: .continuous))
        .contentShape(Capsule())
        .onTapGesture { searchFocused = true }
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

    private var currentEngine: SearchEngine {
        SearchEngine(rawValue: searchEngine) ?? SearchEngine.defaultEngine
    }

    private func submitAddress() {
        if let url = AddressResolver.resolve(address, engine: currentEngine, customTemplate: customSearchTemplate) {
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
                    ForEach(symbols, id: \.self) { name in
                        Button {
                            shortcut.symbolName = name
                        } label: {
                            Image(systemName: name)
                                .frame(width: 40, height: 40)
                                .background(
                                    shortcut.symbolName == name
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(uiColor: .tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(name)
                    }
                }
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
                    let title = shortcut.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    var urlString = shortcut.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !urlString.lowercased().hasPrefix("http://"), !urlString.lowercased().hasPrefix("https://") {
                        urlString = "https://" + urlString
                    }
                    guard !title.isEmpty, URL(string: urlString) != nil else { return }
                    shortcut.title = title
                    shortcut.urlString = urlString
                    onSave(shortcut)
                }
                .disabled(
                    shortcut.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || shortcut.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }
}
