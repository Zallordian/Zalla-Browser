import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

struct BrowserView: View {
    @ObservedObject var browser: BrowserStore
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"
    @State private var sheet: BrowserSheet?

    private var theme: ZallaTheme {
        ZallaTheme.resolved(themeID: themeID, useCustom: useCustomAccent, customHex: customAccentHex)
    }

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
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @AppStorage(AddressBarPlacement.storageKey) private var addressBarPlacementRaw = AddressBarPlacement.bottom.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @State private var address = ""
    @State private var showShare = false
    @State private var isEditingCompactAddress = false
    @State private var isEditingClassicAddress = false
    @FocusState private var addressFocused: Bool

    @State private var holdKind: HoldRevealKind?
    @State private var holdItems: [HoldRevealItem] = []
    @State private var holdHighlightedID: Int?
    @State private var suppressNextNavTap = false
    @State private var holdMenuFrame: CGRect = .zero
    @State private var chromeTipMessage: String?
    @State private var holdRevealTipMessage: String?
    @State private var pendingHoldRevealTip = false
    @AppStorage(ChromeModeTips.compactSeenKey) private var hasSeenCompactTip = false
    @AppStorage(ChromeModeTips.topBarSeenKey) private var hasSeenTopBarTip = false
    @AppStorage(ChromeModeTips.holdRevealSeenKey) private var hasSeenHoldRevealTip = false

    private var theme: ZallaTheme {
        ZallaTheme.resolved(themeID: themeID, useCustom: useCustomAccent, customHex: customAccentHex)
    }
    private var toolbarStyle: ToolbarStyle {
        ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic
    }
    private var addressBarPlacement: AddressBarPlacement {
        AddressBarPlacement(rawValue: addressBarPlacementRaw) ?? .bottom
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
                    VStack(alignment: .leading, spacing: 10) {
                        Text(error)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            Button("Reload") {
                                tab.dismissError()
                                tab.webView.reload()
                            }
                            .font(.caption.weight(.semibold))
                            Button("Stay on page") {
                                tab.dismissError()
                            }
                            .font(.caption.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if addressBarPlacement == .top {
                    topChrome
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if addressBarPlacement == .bottom {
                    bottomChrome
                } else if toolbarStyle == .classic {
                    classicNavOnly
                }
            }

            if holdKind != nil, !holdItems.isEmpty {
                holdRevealOverlay
            }
        }
        .onChange(of: tab.url) { _, url in
            if !addressFocused {
                address = url?.absoluteString ?? ""
                isEditingClassicAddress = false
            }
        }
        .onChange(of: addressFocused) { _, focused in
            if focused {
                if toolbarStyle == .classic {
                    isEditingClassicAddress = true
                    address = AddressDisplay.editingText(url: tab.url).isEmpty ? address : AddressDisplay.editingText(url: tab.url)
                    if address.isEmpty {
                        address = tab.url?.absoluteString ?? ""
                    }
                }
                DispatchQueue.main.async {
                    UIResponder.currentFirstResponder()?.selectAll(nil)
                }
            } else {
                if isEditingCompactAddress {
                    // Collapse Compact chrome when the field resigns (submit, cancel, or blur).
                    isEditingCompactAddress = false
                    address = tab.url?.absoluteString ?? ""
                }
                if isEditingClassicAddress {
                    isEditingClassicAddress = false
                    address = tab.url?.absoluteString ?? ""
                }
            }
        }
        .onAppear {
            address = tab.url?.absoluteString ?? ""
            if toolbarStyle == .compact, !hasSeenCompactTip {
                chromeTipMessage = ChromeModeTips.compactMessage
            } else if addressBarPlacement == .top, !hasSeenTopBarTip {
                chromeTipMessage = ChromeModeTips.topBarMessage
            }
        }
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
        .alert("Compact toolbar", isPresented: Binding(
            get: { chromeTipMessage == ChromeModeTips.compactMessage },
            set: { if !$0 { chromeTipMessage = nil; hasSeenCompactTip = true } }
        )) {
            Button("Got it") { chromeTipMessage = nil; hasSeenCompactTip = true }
        } message: {
            Text(ChromeModeTips.compactMessage)
        }
        .alert("Address bar on top", isPresented: Binding(
            get: { chromeTipMessage == ChromeModeTips.topBarMessage },
            set: { if !$0 { chromeTipMessage = nil; hasSeenTopBarTip = true } }
        )) {
            Button("Got it") { chromeTipMessage = nil; hasSeenTopBarTip = true }
        } message: {
            Text(ChromeModeTips.topBarMessage)
        }
        .alert("History peek", isPresented: Binding(
            get: { holdRevealTipMessage != nil },
            set: { if !$0 { holdRevealTipMessage = nil; hasSeenHoldRevealTip = true } }
        )) {
            Button("Got it") { holdRevealTipMessage = nil; hasSeenHoldRevealTip = true }
        } message: {
            Text(holdRevealTipMessage ?? ChromeModeTips.holdRevealMessage)
        }
        .onChange(of: toolbarStyleRaw) { _, newValue in
            if newValue == ToolbarStyle.compact.rawValue, !hasSeenCompactTip {
                chromeTipMessage = ChromeModeTips.compactMessage
            }
        }
        .onChange(of: addressBarPlacementRaw) { _, newValue in
            if newValue == AddressBarPlacement.top.rawValue, !hasSeenTopBarTip {
                chromeTipMessage = ChromeModeTips.topBarMessage
            }
        }
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
                .padding(.bottom, addressBarPlacement == .top ? 36 : 110)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: HoldMenuFrameKey.self, value: geo.frame(in: .global))
                    }
                )
                .onPreferenceChange(HoldMenuFrameKey.self) { holdMenuFrame = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            holdHighlightedID = HoldRevealMenu.highlightedID(
                                at: value.location,
                                items: holdItems,
                                in: UIScreen.main.bounds,
                                menuFrame: holdMenuFrame
                            ) ?? holdHighlightedID
                        }
                        .onEnded { value in
                            let id = HoldRevealMenu.highlightedID(
                                at: value.location,
                                items: holdItems,
                                in: UIScreen.main.bounds,
                                menuFrame: holdMenuFrame
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
        if !hasSeenHoldRevealTip {
            pendingHoldRevealTip = true
        }
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
        holdMenuFrame = .zero
        if pendingHoldRevealTip, !hasSeenHoldRevealTip {
            pendingHoldRevealTip = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                holdRevealTipMessage = ChromeModeTips.holdRevealMessage
            }
        } else {
            pendingHoldRevealTip = false
        }
    }

    @ViewBuilder
    private var topChrome: some View {
        if toolbarStyle == .classic {
            classicAddressBlock(includeNav: false)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background { chromeMaterial(edges: .top) }
        } else {
            compactToolbar
                .background { chromeMaterial(edges: .top) }
        }
    }

    @ViewBuilder
    private var bottomChrome: some View {
        if toolbarStyle == .classic {
            classicToolbar
        } else {
            compactToolbar
        }
    }

    private var classicToolbar: some View {
        VStack(spacing: 10) {
            classicAddressBlock(includeNav: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background { chromeMaterial(edges: .bottom) }
    }

    private var classicNavOnly: some View {
        VStack(spacing: 0) {
            classicNavRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background { chromeMaterial(edges: .bottom) }
    }

    private func chromeMaterial(edges: Edge.Set) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.28 : 0.55))
            .ignoresSafeArea(edges: edges)
    }

    @ViewBuilder
    private func classicAddressBlock(includeNav: Bool) -> some View {
        VStack(spacing: 10) {
            if tab.isLoading {
                ProgressView(value: tab.progress).tint(theme.primary).accessibilityLabel("Page loading")
            }
            if tab.hasPage || isEditingClassicAddress || addressFocused {
                classicAddressField
            }
            if includeNav {
                classicNavRow
            }
        }
    }

    private var classicAddressField: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.isPrivate ? "eye.slash" : "magnifyingglass")
                .foregroundStyle(.secondary)
            if addressFocused || isEditingClassicAddress {
                TextField("Search or enter a website", text: $address)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.webSearch).submitLabel(.go).focused($addressFocused)
                    .onSubmit { submitAddress() }
                    .accessibilityLabel("Search or website address")
                    .onAppear {
                        if isEditingClassicAddress || isEditingCompactAddress {
                            addressFocused = true
                            DispatchQueue.main.async {
                                UIResponder.currentFirstResponder()?.selectAll(nil)
                            }
                        }
                    }
            } else {
                Text(AddressDisplay.collapsedLabel(url: tab.url, hasPage: tab.hasPage))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { beginClassicAddressEditing() }
                    .accessibilityLabel("Address, \(AddressDisplay.collapsedLabel(url: tab.url, hasPage: tab.hasPage))")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Shows the full URL for editing")
            }
            Button {
                if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
            } label: { Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise") }
            .accessibilityLabel(tab.isLoading ? "Stop loading" : "Reload")
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 16).padding(.trailing, 6).frame(minHeight: 52)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule(style: .continuous))
        .contentShape(Capsule())
        .onTapGesture {
            if !(addressFocused || isEditingClassicAddress) {
                beginClassicAddressEditing()
            }
        }
    }

    private var classicNavRow: some View {
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

    private func beginClassicAddressEditing() {
        address = AddressDisplay.editingText(url: tab.url)
        isEditingClassicAddress = true
        focusAddressFieldSelectingAll()
    }

    /// Focuses the address field after the TextField enters the hierarchy, then selects all.
    private func focusAddressFieldSelectingAll() {
        DispatchQueue.main.async {
            addressFocused = true
            DispatchQueue.main.async {
                UIResponder.currentFirstResponder()?.selectAll(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    UIResponder.currentFirstResponder()?.selectAll(nil)
                }
            }
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
            if isEditingCompactAddress {
                Image(systemName: tab.isPrivate ? "eye.slash" : "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search or enter a website", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($addressFocused)
                    .onSubmit { submitAddress() }
                    .accessibilityLabel("Search or website address")
                    .onAppear {
                        addressFocused = true
                        DispatchQueue.main.async {
                            UIResponder.currentFirstResponder()?.selectAll(nil)
                        }
                    }
                Button {
                    cancelCompactAddressEditing()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Cancel address editing")
                .frame(minWidth: 44, minHeight: 44)
            } else {
                tabsButtonCompact
                VStack(alignment: .leading, spacing: 1) {
                    Text(compactTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if let host = CompactAddressChrome.hostSubtitle(url: tab.url, hasPage: tab.hasPage) {
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
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .contentShape(Capsule())
        // Attach tap-to-edit only while collapsed so the TextField keeps pointer events.
        .modifier(CompactPillInteractionModifier(
            isEditing: isEditingCompactAddress,
            onBeginEditing: beginCompactAddressEditing,
            onCancelEditing: cancelCompactAddressEditing
        ))
    }

    private var compactTitle: String {
        CompactAddressChrome.pillTitle(
            hasPage: tab.hasPage,
            pageTitle: tab.title,
            isReaderActive: tab.isReaderActive
        )
    }

    private func beginCompactAddressEditing() {
        address = CompactAddressChrome.editingPrefill(url: tab.url)
        isEditingCompactAddress = true
        // Focus after the TextField is in the hierarchy.
        focusAddressFieldSelectingAll()
    }

    private func cancelCompactAddressEditing() {
        addressFocused = false
        isEditingCompactAddress = false
        address = tab.url?.absoluteString ?? ""
    }

    private func submitAddress() {
        let engine = SearchEngine(rawValue: searchEngine) ?? .duckDuckGo
        // Always resolve through AddressResolver so search stays inside Zalla's webview.
        guard let url = AddressResolver.resolve(address, engine: engine) else { return }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        tab.load(url)
        addressFocused = false
        isEditingCompactAddress = false
        isEditingClassicAddress = false
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
            .frame(width: 48, height: 48)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
            .opacity(enabled ? 1 : 0.35)
            .accessibilityLabel(label)
            .contentShape(Circle().scale(1.25))
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
        Button { sheet = .downloads } label: { Label("Downloads", systemImage: "arrow.down.circle") }
        Button { sheet = .tabs } label: { Label("All Tabs", systemImage: "square.on.square") }
    }

    private func holdNavButton(label: String, icon: String, enabled: Bool, kind: HoldRevealKind, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .frame(minWidth: 52, minHeight: 52)
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.35)
            .accessibilityLabel(label)
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

    private func holdRevealGesture(kind: HoldRevealKind, enabled: Bool) -> some Gesture {
        LongPressGesture(minimumDuration: 0.28)
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
                            in: UIScreen.main.bounds,
                            menuFrame: holdMenuFrame
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
                            in: UIScreen.main.bounds,
                            menuFrame: holdMenuFrame
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

private struct HoldMenuFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct CompactPillInteractionModifier: ViewModifier {
    let isEditing: Bool
    let onBeginEditing: () -> Void
    let onCancelEditing: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEditing {
            content
                .onKeyPress(.escape) {
                    onCancelEditing()
                    return .handled
                }
        } else {
            content
                .onTapGesture(perform: onBeginEditing)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Double tap to edit address or search")
        }
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
    @State private var confirmCloseAll = false
    @State private var undoClose: (title: String, url: URL?, isPrivate: Bool)?
    @State private var showUndoClose = false

    private let columns = [GridItem(.adaptive(minimum: 156), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(browser.tabs) { tab in
                    TabPreviewCard(
                        tab: tab,
                        selected: tab.id == browser.selectedID,
                        select: {
                            browser.selectTab(tab)
                            dismiss()
                        },
                        close: {
                            undoClose = (tab.title, tab.url, tab.isPrivate)
                            browser.close(tab)
                            showUndoClose = true
                        }
                    )
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .animation(.easeInOut(duration: 0.2), value: browser.tabs.map(\.id))
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Your tabs")
        .safeAreaInset(edge: .bottom) {
            if showUndoClose, let undoClose {
                HStack {
                    Text("Tab closed")
                        .font(.subheadline)
                    Spacer()
                    Button("Undo") {
                        browser.addTab(isPrivate: undoClose.isPrivate, url: undoClose.url)
                        showUndoClose = false
                        self.undoClose = nil
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        showUndoClose = false
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu("New tab", systemImage: "plus") {
                    Button("Regular tab") { browser.addTab(); dismiss() }
                    Button("Private tab") { browser.addTab(isPrivate: true); dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if browser.tabs.count > 1 {
                    Button("Close All", role: .destructive) { confirmCloseAll = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .confirmationDialog("Close all tabs?", isPresented: $confirmCloseAll, titleVisibility: .visible) {
            Button("Close All", role: .destructive) {
                showUndoClose = false
                undoClose = nil
                browser.closeAllTabs()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Opens a fresh tab afterward.")
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
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .clipped()

                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .padding(10)
                        .contentShape(Rectangle())
                        .frame(minWidth: 44, minHeight: 44)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: select)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -80 || value.translation.height < -80 {
                        close()
                    }
                }
        )
        .contextMenu {
            Button(role: .destructive, action: close) {
                Label("Close Tab", systemImage: "xmark")
            }
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
    @AppStorage(HomeShortcuts.washIntensityKey) private var washIntensity = 0.35
    @AppStorage(HomeShortcuts.showLogoKey) private var showLogo = true
    @AppStorage(HomeWelcomeMode.storageKey) private var welcomeModeRaw = HomeWelcomeMode.quotes.rawValue
    @AppStorage(HomeWelcomeMode.userNameKey) private var userName = ""

    var body: some View {
        Form {
            Section("New tab") {
                Toggle("Show Zalla logo", isOn: $showLogo)
                Picker("Welcome", selection: $welcomeModeRaw) {
                    ForEach(HomeWelcomeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                if welcomeModeRaw == HomeWelcomeMode.name.rawValue {
                    TextField("Your name", text: $userName)
                        .textInputAutocapitalization(.words)
                }
                VStack(alignment: .leading) {
                    Text("Background wash")
                    Slider(value: $washIntensity, in: 0...0.6, step: 0.05)
                }
            }
            Section {
                Button("Reset shortcuts to defaults") {
                    HomeShortcuts.resetToDefaults()
                    welcomeModeRaw = HomeWelcomeMode.quotes.rawValue
                    userName = ""
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
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"
    @AppStorage("customAccentGradient") private var customAccentGradient = true
    @AppStorage("appIconPreference") private var appIconPreference = AppIconPreference.default.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @AppStorage(AddressBarPlacement.storageKey) private var addressBarPlacementRaw = AddressBarPlacement.bottom.rawValue
    @State private var confirmClear = false
    @State private var confirmReset = false
    @State private var iconMessage: String?
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var bookmarkMessage: String?
    @State private var customColor = Color(red: 0.89, green: 0.23, blue: 0.31)
    @State private var hexDraft = "E33B4F"
    @State private var redSlider = 0.89
    @State private var greenSlider = 0.23
    @State private var blueSlider = 0.31
    @State private var suggestIconForTheme: ZallaThemeID?

    private var theme: ZallaTheme {
        ZallaTheme.resolved(
            themeID: themeID,
            useCustom: useCustomAccent,
            customHex: customAccentHex,
            gradient: customAccentGradient
        )
    }
    private var versionString: String {
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "6"
        return "\(marketing) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                }
                Picker("Toolbar", selection: $toolbarStyleRaw) {
                    ForEach(ToolbarStyle.allCases) { style in
                        Text(style.rawValue).tag(style.rawValue)
                    }
                }
                Picker("Address bar", selection: $addressBarPlacementRaw) {
                    ForEach(AddressBarPlacement.allCases) { placement in
                        Text(placement.rawValue).tag(placement.rawValue)
                    }
                }
                NavigationLink("Home personalization") {
                    HomePersonalizationView()
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Classic toolbar with a bottom address bar is the default. Compact and Top bar are optional.")
            }

            Section {
                themeRow(title: "Signature", ids: ZallaThemeID.featured)
                DisclosureGroup("More accents") {
                    themeRow(title: nil, ids: ZallaThemeID.secondary)
                }
                Toggle("Custom accent", isOn: $useCustomAccent)
                if useCustomAccent {
                    ColorPicker("Color", selection: $customColor, supportsOpacity: false)
                        .onChange(of: customColor) { _, newValue in
                            syncFromColor(newValue)
                        }
                    VStack(alignment: .leading, spacing: 8) {
                        labeledSlider("Red", value: $redSlider)
                        labeledSlider("Green", value: $greenSlider)
                        labeledSlider("Blue", value: $blueSlider)
                    }
                    .onChange(of: redSlider) { _, _ in syncFromSliders() }
                    .onChange(of: greenSlider) { _, _ in syncFromSliders() }
                    .onChange(of: blueSlider) { _, _ in syncFromSliders() }
                    HStack {
                        Text("#")
                        TextField("Hex", text: $hexDraft)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onSubmit(applyHexDraft)
                        Button("Apply", action: applyHexDraft)
                    }
                    Toggle("Gradient accent", isOn: $customAccentGradient)
                    Button("Use closest matching icon") {
                        let suggested = ZallaTheme.closestAppIcon(forCustomHex: customAccentHex)
                        appIconPreference = suggested.rawValue
                        applyIcon(suggested)
                    }
                }
            } header: {
                Text("Accent")
            } footer: {
                Text("Accents are optional. Zalla Red remains the default. Custom colors map to the closest Default, Dark, or Tinted icon.")
            }

            Section {
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
            } header: {
                Text("App icon")
            } footer: {
                Text("Shipped alternate icons are Default, Dark, and Tinted. Per-accent PNG icons are not included in this build.")
            }

            Section {
                Picker("Search engine", selection: $searchEngine) {
                    ForEach(SearchEngine.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
                Button {
                    showImporter = true
                } label: { Label("Import HTML bookmarks", systemImage: "square.and.arrow.down") }
                Button {
                    exportBookmarks()
                } label: { Label("Export bookmarks", systemImage: "square.and.arrow.up") }
                .disabled(browser.bookmarks.isEmpty)
            } header: {
                Text("Browsing")
            }

            Section("Tools") {
                NavigationLink {
                    NetworkSpeedView()
                } label: {
                    Label("Network Speed", systemImage: "gauge.with.dots.needle.67percent")
                }
                NavigationLink {
                    DownloadsView(browser: browser)
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
            }

            Section {
                Button("Clear browsing data", role: .destructive) { confirmClear = true }
                    .disabled(browser.clearingData)
                Button("Reset the App", role: .destructive) { confirmReset = true }
                    .disabled(browser.clearingData)
            } header: { Text("Privacy") } footer: {
                Text("Clear browsing data closes all tabs and removes history, cookies, and website caches. Bookmarks and downloads are kept. Reset the App also restores appearance, search engine, theme, icon preference, toolbar style, address bar placement, home shortcuts, and onboarding, clears downloads, and keeps bookmarks.")
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
        .confirmationDialog(
            "Use a matching app icon?",
            isPresented: Binding(
                get: { suggestIconForTheme != nil },
                set: { if !$0 { suggestIconForTheme = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let id = suggestIconForTheme {
                let suggested = id.suggestedAppIcon
                Button("Use \(suggested.rawValue) icon") {
                    appIconPreference = suggested.rawValue
                    applyIcon(suggested)
                    suggestIconForTheme = nil
                }
                Button("Keep current icon", role: .cancel) { suggestIconForTheme = nil }
            }
        } message: {
            if let id = suggestIconForTheme {
                Text("\(id.displayName) pairs well with the \(id.suggestedAppIcon.rawValue) icon.")
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
        .onAppear { loadCustomControls() }
    }

    @ViewBuilder
    private func themeRow(title: String?, ids: [ZallaThemeID]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 12) {
                ForEach(ids) { id in
                    let swatch = ZallaTheme.theme(for: id)
                    Button {
                        useCustomAccent = false
                        themeID = id.rawValue
                        suggestIconForTheme = id
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(swatch.gradient)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if !useCustomAccent && themeID == id.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            Text(id.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(id.displayName)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func labeledSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title).frame(width: 52, alignment: .leading)
            Slider(value: value, in: 0...1)
        }
    }

    private func loadCustomControls() {
        hexDraft = ZallaTheme.normalizeHex(customAccentHex) ?? "E33B4F"
        let rgb = ZallaTheme.rgbComponents(from: hexDraft)
        redSlider = rgb.0
        greenSlider = rgb.1
        blueSlider = rgb.2
        customColor = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }

    private func syncFromColor(_ color: Color) {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        redSlider = Double(r)
        greenSlider = Double(g)
        blueSlider = Double(b)
        syncFromSliders()
        #endif
    }

    private func syncFromSliders() {
        let hex = ZallaTheme.hexString(r: redSlider, g: greenSlider, b: blueSlider)
        customAccentHex = hex
        hexDraft = hex
        customColor = Color(red: redSlider, green: greenSlider, blue: blueSlider)
        useCustomAccent = true
    }

    private func applyHexDraft() {
        guard let normalized = ZallaTheme.normalizeHex(hexDraft) else { return }
        customAccentHex = normalized
        hexDraft = normalized
        let rgb = ZallaTheme.rgbComponents(from: normalized)
        redSlider = rgb.0
        greenSlider = rgb.1
        blueSlider = rgb.2
        customColor = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
        useCustomAccent = true
    }

    private func applyIcon(_ preference: AppIconPreference) {
        AppIconPreference.apply(preference) { message in
            if let message {
                iconMessage = message
            } else {
                iconMessage = preference == .default
                    ? "Using the default icon."
                    : "Icon updated to \(preference.rawValue)."
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
