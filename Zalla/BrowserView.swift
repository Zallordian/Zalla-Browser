import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

struct BrowserView: View {
    @ObservedObject var browser: BrowserStore
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @State private var sheet: BrowserSheet?

    private var theme: ZallaTheme { ZallaTheme.theme(forRaw: themeID) }

    var body: some View {
        Group {
            if let tab = browser.selected {
                TabContent(browser: browser, tab: tab, sheet: $sheet)
                    .id(tab.id)
            } else {
                ProgressView("Clearing browsing data...")
            }
        }
        .tint(theme.primary)
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        .sheet(item: $sheet) { item in
            NavigationStack {
                switch item {
                case .tabs: TabsView(browser: browser)
                case .library: LibraryView(browser: browser)
                case .settings: SettingsView(browser: browser)
                case .menu: BrowserMenuSheet(browser: browser, sheet: $sheet)
                case .downloads: DownloadsView(browser: browser)
                case .homePersonalization: HomePersonalizationView()
                }
            }
            .presentationDetents(item == .menu ? [.medium, .large] : [.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $browser.imageExport) { request in
            ImageExportSheet(request: request)
                .presentationDetents([.medium, .large])
        }
        .alert("Local storage", isPresented: Binding(
            get: { browser.storageError != nil },
            set: { if !$0 { browser.storageError = nil } }
        )) {
            Button("OK") { browser.storageError = nil }
        } message: { Text(browser.storageError ?? "") }
    }
}

enum BrowserSheet: String, Identifiable {
    case tabs, library, settings, menu, downloads, homePersonalization
    var id: String { rawValue }
}

private struct TabContent: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @Binding var sheet: BrowserSheet?
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @State private var address = ""
    @State private var showShare = false
    @FocusState private var addressFocused: Bool

    @State private var holdKind: HoldRevealKind?
    @State private var holdItems: [HoldRevealItem] = []
    @State private var holdHighlightedID: Int?
    @State private var suppressNextNavTap = false

    private var theme: ZallaTheme { ZallaTheme.theme(forRaw: themeID) }
    private var toolbarStyle: ToolbarStyle {
        ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if tab.hasPage {
                    WebSurface(webView: tab.webView)
                } else {
                    NewTabView(browser: browser, tab: tab) {
                        sheet = .library
                    }
                }
                if let error = tab.errorMessage {
                    HStack {
                        Text(error).font(.caption)
                        Spacer()
                        Button("Reload") { tab.webView.reload() }
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if toolbarStyle == .classic {
                    classicToolbar
                } else {
                    compactToolbar
                }
            }

            if holdKind != nil, !holdItems.isEmpty {
                holdRevealOverlay
            }
        }
        .onChange(of: tab.url) { _, url in
            if !addressFocused { address = url?.absoluteString ?? "" }
        }
        .onChange(of: addressFocused) { _, focused in
            if focused {
                DispatchQueue.main.async {
                    UIResponder.currentFirstResponder()?.selectAll(nil)
                }
            }
        }
        .onAppear { address = tab.url?.absoluteString ?? "" }
        .sheet(isPresented: $showShare) {
            if let url = tab.url { ActivityShareSheet(items: [url]) }
        }
        .confirmationDialog("Open another app?", isPresented: Binding(
            get: { tab.externalURL != nil },
            set: { if !$0 { tab.externalURL = nil } }
        ), titleVisibility: .visible) {
            if let url = tab.externalURL {
                Button("Open \(url.scheme ?? "link")") {
                    UIApplication.shared.open(url)
                    tab.externalURL = nil
                }
            }
            Button("Cancel", role: .cancel) { tab.externalURL = nil }
        } message: { Text(tab.externalURL?.absoluteString ?? "") }
    }

    private var holdRevealOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { dismissHoldReveal() }

            HoldRevealMenu(items: holdItems, highlightedID: holdHighlightedID) { item in
                    commitHoldReveal(id: item.id)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            holdHighlightedID = HoldRevealMenu.highlightedID(
                                at: value.location,
                                items: holdItems,
                                in: UIScreen.main.bounds
                            ) ?? holdHighlightedID
                        }
                        .onEnded { value in
                            let id = HoldRevealMenu.highlightedID(
                                at: value.location,
                                items: holdItems,
                                in: UIScreen.main.bounds
                            ) ?? holdHighlightedID
                            if let id {
                                commitHoldReveal(id: id)
                            } else {
                                dismissHoldReveal()
                            }
                        }
                )
        }
        .transition(.opacity)
        .zIndex(20)
    }

    private func beginHoldReveal(_ kind: HoldRevealKind) {
        let history: [HistoryListItem]
        switch kind {
        case .back: history = tab.backHistoryItems()
        case .forward: history = tab.forwardHistoryItems()
        }
        guard !history.isEmpty else { return }
        suppressNextNavTap = true
        holdKind = kind
        holdItems = history.map { HoldRevealItem(id: $0.id, title: $0.title, subtitle: $0.host) }
        holdHighlightedID = holdItems.first?.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func commitHoldReveal(id: Int) {
        guard let kind = holdKind,
              let match = (kind == .back ? tab.backHistoryItems() : tab.forwardHistoryItems())
                .first(where: { $0.id == id }) else {
            dismissHoldReveal()
            return
        }
        tab.goToHistoryListItem(match, direction: kind)
        dismissHoldReveal()
    }

    private func dismissHoldReveal() {
        holdKind = nil
        holdItems = []
        holdHighlightedID = nil
    }

    private var classicToolbar: some View {
        VStack(spacing: 10) {
            if tab.isLoading { ProgressView(value: tab.progress).tint(theme.primary).accessibilityLabel("Page loading") }
            if tab.hasPage {
                HStack(spacing: 10) {
                    Image(systemName: tab.isPrivate ? "eye.slash" : "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search or enter a website", text: $address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.webSearch).submitLabel(.go).focused($addressFocused)
                        .onSubmit {
                            if let url = AddressResolver.resolve(address, engine: SearchEngine(rawValue: searchEngine) ?? .duckDuckGo) {
                                tab.load(url)
                                addressFocused = false
                            }
                        }
                        .accessibilityLabel("Search or website address")
                    Button {
                        if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
                    } label: { Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise") }
                    .accessibilityLabel(tab.isLoading ? "Stop loading" : "Reload")
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.leading, 16).padding(.trailing, 6).frame(minHeight: 52)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule(style: .continuous))
            }

            HStack {
                holdNavButton(
                    label: "Back",
                    icon: "chevron.left",
                    enabled: tab.canGoBack,
                    kind: .back
                ) { tab.webView.goBack() }
                Spacer()
                holdNavButton(
                    label: "Forward",
                    icon: "chevron.right",
                    enabled: tab.canGoForward,
                    kind: .forward
                ) { tab.webView.goForward() }
                Spacer()
                control("Share page", icon: "square.and.arrow.up") { showShare = true }.disabled(tab.url == nil)
                Spacer()
                tabsButton
                Spacer()
                Button { sheet = .menu } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Browser menu")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background {
            Color(uiColor: .systemBackground).opacity(0.92)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var compactToolbar: some View {
        VStack(spacing: 8) {
            if tab.isLoading {
                ProgressView(value: tab.progress).tint(theme.primary).padding(.horizontal, 24)
            }
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    compactHoldCircle(
                        icon: "chevron.left",
                        enabled: tab.canGoBack,
                        label: "Back",
                        kind: .back
                    ) { tab.webView.goBack() }

                    compactHoldCircle(
                        icon: "chevron.right",
                        enabled: tab.canGoForward,
                        label: "Forward",
                        kind: .forward
                    ) { tab.webView.goForward() }
                }

                compactPill

                compactCircle(icon: "ellipsis", enabled: true, label: "Browser menu") {
                    sheet = .menu
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color.clear)
    }

    private var compactPill: some View {
        HStack(spacing: 10) {
            tabsButtonCompact
            VStack(alignment: .leading, spacing: 1) {
                Text(compactTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let host = tab.url?.host, tab.hasPage {
                    Text(host)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if tab.hasPage {
                Button {
                    if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
                } label: {
                    Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel(tab.isLoading ? "Stop loading" : "Reload")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .onTapGesture {
            if !tab.hasPage {
                addressFocused = true
            }
        }
    }

    private var compactTitle: String {
        if tab.isReaderActive { return tab.title }
        if tab.hasPage { return tab.title }
        return "Search or enter a website"
    }

    private func compactCircle(icon: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    private func compactHoldCircle(icon: String, enabled: Bool, label: String, kind: HoldRevealKind, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.body.weight(.semibold))
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
            .opacity(enabled ? 1 : 0.35)
            .accessibilityLabel(label)
            .contentShape(Circle())
            .onTapGesture {
                if suppressNextNavTap {
                    suppressNextNavTap = false
                    return
                }
                if enabled { action() }
            }
            .simultaneousGesture(holdRevealGesture(
                kind: kind,
                enabled: enabled && !(kind == .back ? tab.backHistoryItems() : tab.forwardHistoryItems()).isEmpty
            ))
    }

    private var tabsButton: some View {
        Button { sheet = .tabs } label: {
            Text("\(browser.tabs.count)").font(.subheadline.bold())
                .frame(width: 24, height: 26)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(lineWidth: 1.7))
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Tabs, \(browser.tabs.count) open")
        .contextMenu { tabsContextMenu }
    }

    private var tabsButtonCompact: some View {
        Button { sheet = .tabs } label: {
            Image(systemName: tab.isReaderActive ? "doc.plaintext" : "square.on.square")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityLabel("Tabs, \(browser.tabs.count) open")
        .contextMenu { tabsContextMenu }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                // Context menu covers long-press; also available via menu actions.
            }
        )
    }

    @ViewBuilder
    private var tabsContextMenu: some View {
        Button {
            browser.addTab()
            sheet = nil
        } label: { Label("New Tab", systemImage: "plus") }
        Button {
            browser.addTab(isPrivate: true)
            sheet = nil
        } label: { Label("New Private Tab", systemImage: "eye.slash") }
        Divider()
        Button { sheet = .library } label: { Label("Bookmarks", systemImage: "book") }
        Button { sheet = .tabs } label: { Label("All Tabs", systemImage: "square.on.square") }
    }

    private func holdNavButton(label: String, icon: String, enabled: Bool, kind: HoldRevealKind, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .frame(minWidth: 44, minHeight: 44)
            .opacity(enabled ? 1 : 0.35)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .onTapGesture {
                if suppressNextNavTap {
                    suppressNextNavTap = false
                    return
                }
                if enabled { action() }
            }
            .simultaneousGesture(holdRevealGesture(kind: kind, enabled: enabled))
    }

    private func holdRevealGesture(kind: HoldRevealKind, enabled: Bool) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard enabled else { return }
                switch value {
                case .second(true, let drag):
                    if holdKind != kind {
                        beginHoldReveal(kind)
                    }
                    if let drag {
                        holdHighlightedID = HoldRevealMenu.highlightedID(
                            at: drag.location,
                            items: holdItems,
                            in: UIScreen.main.bounds
                        ) ?? holdHighlightedID
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                guard enabled else { return }
                switch value {
                case .second(true, let drag):
                    if let drag {
                        holdHighlightedID = HoldRevealMenu.highlightedID(
                            at: drag.location,
                            items: holdItems,
                            in: UIScreen.main.bounds
                        ) ?? holdHighlightedID
                    }
                    if holdKind != nil, let id = holdHighlightedID {
                        commitHoldReveal(id: id)
                    } else {
                        dismissHoldReveal()
                    }
                default:
                    dismissHoldReveal()
                }
            }
    }

    private func control(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).frame(minWidth: 44, minHeight: 44) }
            .accessibilityLabel(label)
    }
}

private extension UIResponder {
    private static weak var _currentFirstResponder: UIResponder?

    static func currentFirstResponder() -> UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }

    @objc private func findFirstResponder(_ sender: Any?) {
        UIResponder._currentFirstResponder = self
    }
}

private struct WebSurface: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct BrowserMenuSheet: View {
    @ObservedObject var browser: BrowserStore
    @Binding var sheet: BrowserSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Section("Page actions") {
                Button {
                    browser.addTab()
                    dismiss()
                } label: { Label("New tab", systemImage: "plus") }
                Button {
                    browser.addTab(isPrivate: true)
                    dismiss()
                } label: { Label("New private tab", systemImage: "eye.slash") }
                Button {
                    browser.selected?.findOnPage()
                    dismiss()
                } label: { Label("Find on page", systemImage: "text.magnifyingglass") }
                .disabled(!(browser.selected?.hasPage ?? false))
                Button {
                    if let tab = browser.selected {
                        tab.toggleReaderMode(dark: colorScheme == .dark)
                    }
                    dismiss()
                } label: {
                    Label(
                        browser.selected?.isReaderActive == true ? "Exit reader" : "Reader mode",
                        systemImage: "doc.plaintext"
                    )
                }
                .disabled(!(browser.selected?.hasPage ?? false))
                Button {
                    if let tab = browser.selected { browser.bookmark(tab) }
                    dismiss()
                } label: { Label("Bookmark page", systemImage: "bookmark") }
                .disabled(browser.selected?.url == nil)
            }
            Section("Library") {
                Button {
                    sheet = .library
                } label: { Label("Bookmarks and history", systemImage: "books.vertical") }
                Button {
                    sheet = .downloads
                } label: { Label("Downloads", systemImage: "arrow.down.circle") }
            }
            Section("Settings") {
                Button {
                    sheet = .settings
                } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }
}

private struct TabsView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(browser.tabs) { tab in
                    TabPreviewCard(
                        tab: tab,
                        selected: tab.id == browser.selectedID,
                        select: {
                            browser.selectTab(tab)
                            dismiss()
                        },
                        close: { browser.close(tab) }
                    )
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Your tabs")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu("New tab", systemImage: "plus") {
                    Button("Regular tab") { browser.addTab(); dismiss() }
                    Button("Private tab") { browser.addTab(isPrivate: true); dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }
}

private struct TabPreviewCard: View {
    @ObservedObject var tab: BrowserTab
    let selected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = tab.previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(uiColor: .secondarySystemFill)
                            .overlay {
                                Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(height: 120)
                .clipped()

                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .padding(8)
                }
                .accessibilityLabel("Close \(tab.title)")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(tab.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if tab.isPrivate {
                        Text("Private")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.12), in: Capsule())
                    }
                }
                Text(tab.url?.host ?? "Built around you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: select)
    }
}

private struct LibraryView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @State private var history = false
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var message: String?
    @State private var query = ""
    @State private var renameTarget: SavedPage?
    @State private var renameText = ""

    private var filtered: [SavedPage] {
        let pages = history ? browser.history : browser.bookmarks
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pages }
        return pages.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.url.absoluteString.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        List {
            Picker("Library", selection: $history) {
                Text("Bookmarks").tag(false)
                Text("History").tag(true)
            }.pickerStyle(.segmented)

            Section {
                TextField("Search", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if !history {
                Section {
                    Button {
                        showImporter = true
                    } label: { Label("Import HTML bookmarks", systemImage: "square.and.arrow.down") }
                    Button {
                        exportBookmarks()
                    } label: { Label("Export bookmarks", systemImage: "square.and.arrow.up") }
                    .disabled(browser.bookmarks.isEmpty)
                }
            }

            if filtered.isEmpty {
                Text(history ? "No browsing history" : "No bookmarks yet").foregroundStyle(.secondary)
            }
            ForEach(filtered) { page in
                Button {
                    browser.selected?.load(page.url)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(page.title).lineLimit(1)
                        Text(page.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: !history) {
                    if !history {
                        Button(role: .destructive) {
                            browser.removeBookmark(id: page.id)
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            renameTarget = page
                            renameText = page.title
                        } label: { Label("Rename", systemImage: "pencil") }
                        .tint(.indigo)
                    }
                }
                .contextMenu {
                    if !history {
                        Button {
                            renameTarget = page
                            renameText = page.title
                        } label: { Label("Rename", systemImage: "pencil") }
                        Button(role: .destructive) {
                            browser.removeBookmark(id: page.id)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("Your library")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.html, .text],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ActivityShareSheet(items: [exportURL])
            }
        }
        .alert("Bookmarks", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
        .alert("Rename bookmark", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if let target = renameTarget {
                    browser.renameBookmark(id: target.id, title: renameText)
                }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
    }

    private func exportBookmarks() {
        do {
            exportURL = try BookmarkHTML.writeTemporaryExport(bookmarks: browser.bookmarks)
            showExporter = true
        } catch {
            message = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            message = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let added = browser.importBookmarks(BookmarkHTML.parse(text))
                message = added == 0
                    ? "No new bookmarks were found in that file."
                    : "Imported \(added) bookmark\(added == 1 ? "" : "s")."
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

private struct DownloadsView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var confirmClear = false

    var body: some View {
        List {
            if browser.downloads.isEmpty {
                Text("No downloads yet").foregroundStyle(.secondary)
            }
            ForEach(browser.downloads) { record in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(record.filename).font(.subheadline.weight(.semibold)).lineLimit(1)
                        if record.isPrivate {
                            Text("Private")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                        Text(stateLabel(record.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(record.sourceURL.host ?? record.sourceURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack {
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let bytes = record.byteCount {
                            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if record.state == .completed, let fileURL = record.localFileURL {
                        HStack {
                            Button("Open") {
                                shareURL = fileURL
                                showShare = true
                            }
                            Button("Share") {
                                shareURL = fileURL
                                showShare = true
                            }
                            Button("Delete", role: .destructive) {
                                browser.removeDownload(record)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderless)
                    } else if record.state == .failed {
                        Button("Delete", role: .destructive) {
                            browser.removeDownload(record)
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                let items = offsets.map { browser.downloads[$0] }
                items.forEach { browser.removeDownload($0) }
            }

            if !browser.downloads.isEmpty {
                Section {
                    Button("Clear all downloads", role: .destructive) { confirmClear = true }
                }
            }
        }
        .navigationTitle("Downloads")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ActivityShareSheet(items: [shareURL])
            }
        }
        .confirmationDialog("Clear all downloads?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear all", role: .destructive) { browser.clearAllDownloads() }
        }
    }

    private func stateLabel(_ state: DownloadState) -> String {
        switch state {
        case .downloading: return "Downloading"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

private struct HomePersonalizationView: View {
    @AppStorage(HomeShortcuts.showRecentHistoryKey) private var showRecentHistory = true
    @AppStorage(HomeShortcuts.washIntensityKey) private var washIntensity = 0.35
    @AppStorage(HomeShortcuts.showLogoKey) private var showLogo = true

    var body: some View {
        Form {
            Section("New tab") {
                Toggle("Show Zalla logo", isOn: $showLogo)
                Toggle("Show recent history chips", isOn: $showRecentHistory)
                VStack(alignment: .leading) {
                    Text("Background wash")
                    Slider(value: $washIntensity, in: 0...0.6, step: 0.05)
                }
            }
            Section {
                Button("Reset shortcuts to defaults") {
                    HomeShortcuts.resetToDefaults()
                }
            } footer: {
                Text("Shortcuts themselves are edited from the new tab Edit button. Reset restores the default shortcut set and these toggles.")
            }
        }
        .navigationTitle("Home")
    }
}

private struct SettingsView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("appIconPreference") private var appIconPreference = AppIconPreference.default.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @State private var confirmClear = false
    @State private var confirmReset = false
    @State private var iconMessage: String?
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var bookmarkMessage: String?

    private var theme: ZallaTheme { ZallaTheme.theme(forRaw: themeID) }
    private var versionString: String {
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3"
        return "\(marketing) (\(build))"
    }

    var body: some View {
        Form {
            Section("Built around you") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                }
                Picker("Search engine", selection: $searchEngine) {
                    ForEach(SearchEngine.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("Toolbar", selection: $toolbarStyleRaw) {
                    ForEach(ToolbarStyle.allCases) { style in
                        Text(style.rawValue).tag(style.rawValue)
                    }
                }
            }

            Section("New tab page") {
                NavigationLink("Home personalization") {
                    HomePersonalizationView()
                }
            }

            Section("Accent theme") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                    ForEach(ZallaThemeID.allCases) { id in
                        let swatch = ZallaTheme.theme(for: id)
                        Button {
                            themeID = id.rawValue
                        } label: {
                            Circle()
                                .fill(swatch.gradient)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if themeID == id.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .accessibilityLabel(id.displayName)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("App icon") {
                Picker("Icon", selection: $appIconPreference) {
                    ForEach(AppIconPreference.allCases) { option in
                        Text(option.rawValue).tag(option.rawValue)
                    }
                }
                .onChange(of: appIconPreference) { _, newValue in
                    applyIcon(AppIconPreference(rawValue: newValue) ?? .default)
                }
                if let iconMessage {
                    Text(iconMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Bookmarks") {
                Button {
                    showImporter = true
                } label: { Label("Import HTML bookmarks", systemImage: "square.and.arrow.down") }
                Button {
                    exportBookmarks()
                } label: { Label("Export bookmarks", systemImage: "square.and.arrow.up") }
                .disabled(browser.bookmarks.isEmpty)
            }

            Section {
                Button("Clear browsing data", role: .destructive) { confirmClear = true }
                    .disabled(browser.clearingData)
                Button("Reset the App", role: .destructive) { confirmReset = true }
                    .disabled(browser.clearingData)
            } header: { Text("Privacy") } footer: {
                Text("Clear browsing data closes all tabs and removes history, cookies, and website caches. Bookmarks and downloads are kept. Reset the App also restores appearance, search engine, theme, icon preference, toolbar style, home shortcuts, and onboarding, clears downloads, and keeps bookmarks.")
            }

            Section("Our promise") {
                Label("No Zalla account required", systemImage: "person.crop.circle.badge.checkmark")
                Label("No built-in analytics or advertising SDKs", systemImage: "hand.raised")
                Label("Bookmarks and history saved on this device", systemImage: "iphone")
                Text("Websites and your chosen search engine receive the requests you send them. Zalla does not provide a VPN or anonymity service.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Version") {
                Text("Zalla \(versionString)")
                Text("Core browsing remains free. Optional creative tools are planned as a single lifetime purchase around $1. Image export is free in this build.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .confirmationDialog("Clear browsing data and close all tabs?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear browsing data", role: .destructive) {
                Task { await browser.clearBrowsingData(); dismiss() }
            }
        }
        .confirmationDialog("Reset the App? Bookmarks are kept.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset the App", role: .destructive) {
                Task {
                    await browser.resetApp(keepingBookmarks: true)
                    hasCompletedOnboarding = false
                    dismiss()
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.html, .text],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ActivityShareSheet(items: [exportURL])
            }
        }
        .alert("Bookmarks", isPresented: Binding(
            get: { bookmarkMessage != nil },
            set: { if !$0 { bookmarkMessage = nil } }
        )) {
            Button("OK") { bookmarkMessage = nil }
        } message: { Text(bookmarkMessage ?? "") }
        .tint(theme.primary)
    }

    private func applyIcon(_ preference: AppIconPreference) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconMessage = "Alternate icons need a TestFlight or App Store build with CFBundleAlternateIcons configured."
            return
        }
        let name = preference.alternateIconName
        if UIApplication.shared.alternateIconName == name {
            iconMessage = nil
            return
        }
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                if let error {
                    iconMessage = error.localizedDescription
                } else {
                    iconMessage = preference == .default
                        ? "Using the default icon."
                        : "Icon updated to \(preference.rawValue)."
                }
            }
        }
    }

    private func exportBookmarks() {
        do {
            exportURL = try BookmarkHTML.writeTemporaryExport(bookmarks: browser.bookmarks)
            showExporter = true
        } catch {
            bookmarkMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            bookmarkMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let added = browser.importBookmarks(BookmarkHTML.parse(text))
                bookmarkMessage = added == 0
                    ? "No new bookmarks were found in that file."
                    : "Imported \(added) bookmark\(added == 1 ? "" : "s")."
            } catch {
                bookmarkMessage = error.localizedDescription
            }
        }
    }
}
