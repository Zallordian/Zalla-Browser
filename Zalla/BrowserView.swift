import SwiftUI
import WebKit

struct BrowserView: View {
    @ObservedObject var browser: BrowserStore
    @AppStorage("appearance") private var appearance = "System"
    @State private var sheet: BrowserSheet?

    var body: some View {
        Group {
            if let tab = browser.selected {
                TabContent(browser: browser, tab: tab, sheet: $sheet)
                    .id(tab.id)
            } else {
                ProgressView("Clearing browsing data…")
            }
        }
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        .sheet(item: $sheet) { item in
            NavigationStack {
                switch item {
                case .tabs: TabsView(browser: browser)
                case .library: LibraryView(browser: browser)
                case .settings: SettingsView(browser: browser)
                }
            }
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
    case tabs, library, settings
    var id: String { rawValue }
}

private struct TabContent: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @Binding var sheet: BrowserSheet?
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @State private var address = ""
    @State private var showShare = false
    @FocusState private var addressFocused: Bool

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
                .padding().background(.regularMaterial)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { toolbar }
        .onChange(of: tab.url) { _, url in
            if !addressFocused { address = url?.absoluteString ?? "" }
        }
        .onAppear { address = tab.url?.absoluteString ?? "" }
        .sheet(isPresented: $showShare) {
            if let url = tab.url { ShareSheet(url: url) }
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
                        .font(.title2).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tab.isPrivate ? "Just for this tab" : "Your space. On your device.")
                            .font(.headline)
                        Text(tab.isPrivate
                             ? "This tab won’t save browsing history or website data to disk. Websites and your network can still see your activity."
                             : "No Zalla account. No built-in analytics. Your bookmarks and history stay in your local library.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))

                HStack {
                    Text("Your favorites").font(.headline)
                    Spacer()
                    Button("View all") { sheet = .library }.font(.subheadline)
                }
                if browser.bookmarks.isEmpty {
                    Text("Make yourself at home. Bookmark a page from the menu and it will appear here.")
                        .foregroundStyle(.secondary).font(.subheadline)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 12) {
                        ForEach(Array(browser.bookmarks.prefix(6))) { page in
                            Button { tab.load(page.url) } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: "globe").font(.title2)
                                    Text(page.title).font(.subheadline.bold()).lineLimit(1)
                                    Text(page.url.host ?? "").font(.caption).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
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
                    RadialGradient(colors: [Color.red.opacity(0.14), .clear], center: .topTrailing,
                                   startRadius: 0, endRadius: 380)
                }.ignoresSafeArea()
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            if tab.isLoading { ProgressView(value: tab.progress).accessibilityLabel("Page loading") }
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
            .padding(.leading, 14).padding(.trailing, 4).frame(minHeight: 50)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 17))

            HStack {
                control("Back", icon: "chevron.left") { tab.webView.goBack() }.disabled(!tab.canGoBack)
                Spacer()
                control("Forward", icon: "chevron.right") { tab.webView.goForward() }.disabled(!tab.canGoForward)
                Spacer()
                control("Share page", icon: "square.and.arrow.up") { showShare = true }.disabled(tab.url == nil)
                Spacer()
                Button { sheet = .tabs } label: {
                    Text("\(browser.tabs.count)").font(.subheadline.bold())
                        .frame(width: 23, height: 25)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 1.7))
                        .frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Tabs, \(browser.tabs.count) open")
                Spacer()
                Menu {
                    Button("New tab", systemImage: "plus") { browser.addTab() }
                    Button("New private tab", systemImage: "eye.slash") { browser.addTab(isPrivate: true) }
                    Button("Find on page", systemImage: "text.magnifyingglass") { tab.findOnPage() }
                        .disabled(!tab.hasPage)
                    Button("Bookmark page", systemImage: "bookmark") { browser.bookmark(tab) }.disabled(tab.url == nil)
                    Button("Bookmarks & history", systemImage: "books.vertical") { sheet = .library }
                    Button("Settings", systemImage: "gearshape") { sheet = .settings }
                } label: { Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Browser menu")
            }
        }.padding(.horizontal, 16).padding(.top, 8).background(.regularMaterial)
    }

    private func control(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).frame(minWidth: 44, minHeight: 44) }
            .accessibilityLabel(label)
    }
}

private struct WebSurface: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
    var body: some View {
        List {
            Picker("Library", selection: $history) {
                Text("Bookmarks").tag(false)
                Text("History").tag(true)
            }.pickerStyle(.segmented)
            let pages = history ? browser.history : browser.bookmarks
            if pages.isEmpty { Text(history ? "No browsing history" : "No bookmarks yet").foregroundStyle(.secondary) }
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
    }
}

private struct SettingsView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @State private var confirmClear = false
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
            Section {
                Button("Clear browsing data", role: .destructive) { confirmClear = true }
                    .disabled(browser.clearingData)
            } header: { Text("Privacy") } footer: {
                Text("Closes all tabs and removes history, cookies, and website caches. Bookmarks are kept. Private tabs use memory-only website storage. Private browsing does not make you anonymous.")
            }
            Section("Our promise") {
                Label("No Zalla account required", systemImage: "person.crop.circle.badge.checkmark")
                Label("No built-in analytics or advertising SDKs", systemImage: "hand.raised")
                Label("Bookmarks and history saved on this device", systemImage: "iphone")
                Text("Websites and your chosen search engine receive the requests you send them. Zalla does not provide a VPN or anonymity service.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Early development build") {
                Text("0.1 · Browser foundation")
                Text("Core browsing will remain free. Optional creative tools are planned as a single lifetime purchase around $1. No purchases are available in this build.")
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
    }
}
