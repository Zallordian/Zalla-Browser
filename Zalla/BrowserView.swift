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
    case tabs, library, settings, menu
    var id: String { rawValue }
}

private struct TabContent: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @Binding var sheet: BrowserSheet?
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @State private var address = ""
    @State private var showShare = false
    @FocusState private var addressFocused: Bool

    private var theme: ZallaTheme { ZallaTheme.theme(forRaw: themeID) }

    var body: some View {
        VStack(spacing: 0) {
            if tab.hasPage {
                WebSurface(webView: tab.webView)
            } else {
                startPage
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
        .safeAreaInset(edge: .bottom, spacing: 0) { toolbar }
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

    private var startPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Label("ZALLA", systemImage: "sparkle")
                        .font(.caption.bold()).tracking(4)
                    Spacer()
                    if tab.isPrivate {
                        Label("Private", systemImage: "eye.slash").font(.caption)
                    }
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text("A little more\nyour internet.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Built around you.")
                        .font(.title3).foregroundStyle(.secondary)
                }
                .padding(.vertical, 18)

                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: tab.isPrivate ? "eye.slash.fill" : "iphone")
                        .font(.title2).foregroundStyle(theme.primary)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tab.isPrivate ? "Just for this tab" : "Your space. On your device.")
                            .font(.headline)
                        Text(tab.isPrivate
                             ? "This tab will not save browsing history or website data to disk. Websites and your network can still see your activity."
                             : "No Zalla account. No built-in analytics. Your bookmarks and history stay in your local library.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(22)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                HStack {
                    Text("Your favorites").font(.headline)
                    Spacer()
                    Button("View all") { sheet = .library }.font(.subheadline)
                }
                if browser.bookmarks.isEmpty {
                    Text("Make yourself at home. Bookmark a page from the menu and it will appear here.")
                        .foregroundStyle(.secondary).font(.subheadline)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 14) {
                        ForEach(Array(browser.bookmarks.prefix(6))) { page in
                            Button { tab.load(page.url) } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: "globe").font(.title2).foregroundStyle(theme.primary)
                                    Text(page.title).font(.subheadline.bold()).lineLimit(1)
                                    Text(page.url.host ?? "").font(.caption).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Spacer(minLength: 24)
            }.padding(24)
        }
        .background {
            Color(uiColor: .systemGroupedBackground)
                .overlay(alignment: .topTrailing) {
                    RadialGradient(colors: [theme.primary.opacity(0.14), .clear], center: .topTrailing,
                                   startRadius: 0, endRadius: 380)
                }.ignoresSafeArea()
        }
    }

    private var toolbar: some View {
        VStack(spacing: 10) {
            if tab.isLoading { ProgressView(value: tab.progress).tint(theme.primary).accessibilityLabel("Page loading") }
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
                if tab.hasPage {
                    Button {
                        if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
                    } label: { Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise") }
                    .accessibilityLabel(tab.isLoading ? "Stop loading" : "Reload")
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.leading, 16).padding(.trailing, 6).frame(minHeight: 52)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule(style: .continuous))

            HStack {
                control("Back", icon: "chevron.left") { tab.webView.goBack() }.disabled(!tab.canGoBack)
                Spacer()
                control("Forward", icon: "chevron.right") { tab.webView.goForward() }.disabled(!tab.canGoForward)
                Spacer()
                control("Share page", icon: "square.and.arrow.up") { showShare = true }.disabled(tab.url == nil)
                Spacer()
                Button { sheet = .tabs } label: {
                    Text("\(browser.tabs.count)").font(.subheadline.bold())
                        .frame(width: 24, height: 26)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(lineWidth: 1.7))
                        .frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Tabs, \(browser.tabs.count) open")
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
                    if let tab = browser.selected { browser.bookmark(tab) }
                    dismiss()
                } label: { Label("Bookmark page", systemImage: "bookmark") }
                .disabled(browser.selected?.url == nil)
            }
            Section("Library") {
                Button {
                    sheet = .library
                } label: { Label("Bookmarks and history", systemImage: "books.vertical") }
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

    var body: some View {
        List {
            ForEach(browser.tabs) { tab in
                TabRow(tab: tab, selected: tab.id == browser.selectedID) {
                    browser.selectedID = tab.id
                    dismiss()
                } close: { browser.close(tab) }
            }
        }
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

private struct TabRow: View {
    @ObservedObject var tab: BrowserTab
    let selected: Bool
    let select: () -> Void
    let close: () -> Void
    var body: some View {
        HStack {
            Button(action: select) {
                HStack {
                    Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
                    VStack(alignment: .leading) {
                        Text(tab.title).lineLimit(1)
                        Text(tab.url?.host ?? "Built around you.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selected { Image(systemName: "checkmark") }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .buttonStyle(.borderless).accessibilityLabel("Close \(tab.title)")
        }
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

    var body: some View {
        List {
            Picker("Library", selection: $history) {
                Text("Bookmarks").tag(false)
                Text("History").tag(true)
            }.pickerStyle(.segmented)

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

            let pages = history ? browser.history : browser.bookmarks
            if pages.isEmpty {
                Text(history ? "No browsing history" : "No bookmarks yet").foregroundStyle(.secondary)
            }
            ForEach(pages) { page in
                Button {
                    browser.selected?.load(page.url)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(page.title).lineLimit(1)
                        Text(page.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }.onDelete { offsets in
                if !history { browser.removeBookmarks(at: offsets) }
            }.deleteDisabled(history)
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

private struct SettingsView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("appIconPreference") private var appIconPreference = AppIconPreference.default.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
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
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
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
                Text("Clear browsing data closes all tabs and removes history, cookies, and website caches. Bookmarks are kept. Reset the App also restores appearance, search engine, theme, icon preference, and onboarding, while keeping bookmarks.")
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
