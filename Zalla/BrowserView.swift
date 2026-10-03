import SwiftUI
import UIKit
import QuickLook
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
            } else if browser.isBurning {
                // Burn It All draws its own label over this. Nothing else may show one underneath.
                (browser.burnPlan?.style == .fade ? Color(uiColor: .systemBackground) : Color.black)
                    .ignoresSafeArea()
            } else {
                ProgressView("Clearing browsing data...")
            }
        }
        .tint(theme.primary)
        // While a private tab is locked, VoiceOver must not read the page hidden behind the lock screen.
        .accessibilityHidden(browser.privateLocked && browser.selected?.isPrivate == true)
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        .sheet(item: $sheet) { item in
            NavigationStack {
                switch item {
                case .tabs: TabsView(browser: browser)
                case .library: LibraryView(browser: browser)
                case .settings: SettingsView(browser: browser)
                case .menu: BrowserMenuSheet(browser: browser, sheet: $sheet)
                case .downloads: DownloadsView(browser: browser)
                case .pageZoom:
                    if let tab = browser.selected {
                        PageZoomSheet(tab: tab)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .presentationDetents(detents(for: item))
            .presentationDragIndicator(.visible)
        }
        .onChange(of: browser.pendingQuickAction) { _, action in
            if let action { runQuickAction(action) }
        }
        .onAppear {
            if let action = browser.pendingQuickAction { runQuickAction(action) }
        }
        .overlay {
            if browser.privateLocked, browser.selected?.isPrivate == true {
                PrivateLockView(browser: browser)
            }
        }
        .overlay {
            if browser.isBurning { BurnOverlay(plan: browser.burnPlan ?? BurnEffectPlan.make(reduceMotion: false)) }
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

extension BrowserView {
    /// Carries out an app icon quick action or widget link. Anything open on top (a sheet) is put away first,
    /// then the step runs. Burn only opens its confirmation.
    private func runQuickAction(_ action: QuickAction) {
        browser.pendingQuickAction = nil
        let hadSheet = sheet != nil
        if action.step != .openLibrary { sheet = nil }
        Task { @MainActor in
            // Give a closing sheet a moment before the address bar or the confirmation takes over.
            if hadSheet, action.step == .focusAddressBar || action.step == .confirmBurn {
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
            switch action.step {
            case .newTab: browser.openNewTabFromQuickAction()
            case .newPrivateTab: await browser.openPrivateTab()
            case .focusAddressBar: browser.addressFocusRequest += 1
            case .openLibrary: sheet = .library
            case .confirmBurn: browser.burnConfirmRequest += 1
            }
        }
    }

    private func detents(for item: BrowserSheet) -> Set<PresentationDetent> {
        switch item {
        case .menu: return [.medium, .large]
        case .pageZoom: return [.height(300)]
        default: return [.large]
        }
    }
}

enum BrowserSheet: String, Identifiable {
    case tabs, library, settings, menu, downloads, pageZoom
    var id: String { rawValue }
}

private struct TabContent: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @Binding var sheet: BrowserSheet?
    @AppStorage(SearchEngine.storageKey) private var searchEngine = SearchEngine.defaultEngine.rawValue
    @AppStorage(SearchEngine.customTemplateKey) private var customSearchTemplate = ""
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @AppStorage(AddressBarPlacement.storageKey) private var addressBarPlacementRaw = AddressBarPlacement.bottom.rawValue
    @AppStorage(ToolbarLayout.storageKey) private var toolbarLayoutData = Data()
    @AppStorage(SearchBarWidth.storageKey) private var searchBarWidthValue = SearchBarWidth.full
    @AppStorage(ImmersiveLayout.storageKey) private var immersiveLayout = ImmersiveLayout.defaultEnabled
    @AppStorage(PageColor.storageKey) private var statusBarMatchesPage = PageColor.defaultEnabled
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage(AppBanner.storageKey) private var appBannersOn = AppBanner.defaultEnabled
    @ObservedObject private var appBannerSession = AppBannerSession.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ThemePacks.transitionsKey) private var transitionsOn = true
    @AppStorage(ThemeTransitionSpeed.storageKey) private var transitionSpeedRaw = ThemeTransitionSpeed.normal.rawValue
    @ObservedObject private var unlockState = ZallaUnlock.shared
    @AppStorage(SwipeNavigation.storageKey) private var swipeNavigationOn = true
    @State private var address = ""
    @State private var showShare = false
    @State private var confirmBurn = false
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
    @AppStorage(ChromeModeTips.quickActionSeenKey) private var hasSeenQuickActionTip = false
    @State private var quickActionOpen = false
    @State private var quickActionFrame: CGRect = .zero
    @State private var showSearchPageInfo = false
    @State private var suppressSearchTap = false
    @Namespace private var addressNamespace
    /// Measured heights of the floating chrome (inside the safe area) so content can scroll clear of it.
    @State private var topChromeHeight: CGFloat = 0
    @State private var bottomChromeHeight: CGFloat = 0
    /// Home indicator inset of the device, remembered while the keyboard is away (immersive layout).
    @State private var homeIndicatorInset: CGFloat = 0
    /// The color scheme actually applied for the status bar text. It follows `statusBarScheme`, but a switch between
    /// light and dark waits a moment so a page that flickers near mid gray does not flip the whole app back and forth.
    @State private var appliedStatusBarScheme: ColorScheme?

    private var theme: ZallaTheme {
        ZallaTheme.resolved(themeID: themeID, useCustom: useCustomAccent, customHex: customAccentHex)
    }
    private var toolbarStyle: ToolbarStyle {
        ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic
    }
    private var addressBarPlacement: AddressBarPlacement {
        AddressBarPlacement(rawValue: addressBarPlacementRaw) ?? .bottom
    }
    private var toolbarLayout: ToolbarLayout {
        ToolbarLayout.decode(toolbarLayoutData)
    }
    /// The "Open in the app" banner to show now, if any: the page has the tag, the setting is on, and it was not dismissed.
    private var visibleAppBanner: AppBannerInfo? {
        guard appBannersOn, !addressFocused, let info = tab.appBanner,
              !appBannerSession.isDismissed(info.hostKey, isPrivate: tab.isPrivate) else { return nil }
        return info
    }

    /// Tries the app's universal link and nothing else. If the app is not installed the system refuses and
    /// nothing happens. Either way the banner goes away for this host until Zalla closes.
    private func openAppBanner(_ info: AppBannerInfo) {
        appBannerSession.dismiss(info.hostKey, isPrivate: tab.isPrivate)
        guard let target = AppBanner.openURL(for: info, pageURL: tab.url) else { return }
        UIApplication.shared.open(target, options: [.universalLinksOnly: true], completionHandler: nil)
    }

    /// What to paint above the page, and whether the status bar text should lean light or dark.
    private var statusBarPlan: PageColor.StatusBarPlan {
        PageColor.plan(
            immersive: immersiveLayout,
            matchPage: statusBarMatchesPage,
            hasPage: tab.hasPage,
            sample: tab.isReaderActive ? nil : tab.pageColor,
            appearance: appearance,
            isDark: tab.pageColorIsDark
        )
    }
    /// Safe-area edges the page layer extends into. The top stays out while the status bar strip is painted. The
    /// scroll view then adds no automatic top inset of its own, so the chrome height alone keeps the page clear of
    /// the banner and top bar.
    private var webSurfaceIgnoredEdges: Edge.Set {
        statusBarPlan.startsBelowStatusBar ? [.bottom, .horizontal] : .all
    }
    /// A control dimension: a little smaller in the immersive layout, unchanged for the solid bars.
    private func barSize(_ value: CGFloat) -> CGFloat {
        ImmersiveLayout.size(value, immersive: immersiveLayout)
    }
    private var barIconFont: Font {
        immersiveLayout ? .subheadline.weight(.semibold) : .body.weight(.semibold)
    }
    /// Bottom inset for page content. In the immersive layout the capsule sits inside the home indicator
    /// inset the system already adds, so that slack is not counted twice.
    private var bottomContentInset: CGFloat {
        ImmersiveLayout.bottomContentInset(
            barHeight: bottomChromeHeight,
            homeIndicatorInset: homeIndicatorInset,
            immersive: immersiveLayout
        )
    }

    var body: some View {
        ZStack {
            // Page layer runs edge to edge, under the chrome and into the safe areas.
            if tab.hasPage {
                WebSurface(
                    webView: tab.webView,
                    chromeInsets: UIEdgeInsets(top: topChromeHeight, left: 0, bottom: bottomContentInset, right: 0)
                )
                // Container only: the keyboard still resizes the page like before. While the status bar strip is
                // painted the page frame starts below the clock (top safe area respected), so a site's fixed
                // header is not hidden under the strip. Otherwise edge to edge, as in Build 23.
                .ignoresSafeArea(.container, edges: webSurfaceIgnoredEdges)
            } else {
                NewTabView(
                    browser: browser,
                    tab: tab,
                    onOpenLibrary: { sheet = .library },
                    onOpenTabs: { sheet = .tabs }
                )
                .fadesInOnAppear()
                // Extra safe area so home content starts clear of the bars but still scrolls under them.
                .safeAreaPadding(.top, topChromeHeight)
                .safeAreaPadding(.bottom, bottomContentInset)
                .overlay(alignment: .trailing) { newTabForwardSwipe }
            }

            statusBarStrip

            if let fallback = tab.httpsFallback {
                ZStack {
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                    HTTPSFallbackView(
                        host: fallback.host,
                        theme: theme,
                        onGoBack: { tab.leaveHTTPSFallback() },
                        onContinue: { tab.continueOverHTTP() }
                    )
                    .safeAreaPadding(.top, topChromeHeight)
                    .safeAreaPadding(.bottom, bottomContentInset)
                }
            }

            if let failure = tab.pageError {
                ZStack {
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                    FriendlyErrorView(
                        error: failure,
                        theme: theme,
                        onRetry: { tab.retryFailedPage() },
                        onDismiss: { tab.dismissError() }
                    )
                    .safeAreaPadding(.top, topChromeHeight)
                    .safeAreaPadding(.bottom, bottomContentInset)
                }
            }

            Group {
                if tab.isPickingElement {
                    ElementPickerBanner(onCancel: { tab.cancelElementPicker() })
                        .padding(.top, topChromeHeight + 8)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                }
            }
            .motion(.fade, value: tab.isPickingElement)
            .zIndex(5)

            ThemeTransitionOverlay(
                plan: ThemePacks.activeTransition(
                    themeID: themeID,
                    useCustomAccent: useCustomAccent,
                    unlocked: unlockState.isUnlocked,
                    enabled: transitionsOn,
                    reduceMotion: reduceMotion,
                    speed: ThemeTransitionSpeed(stored: transitionSpeedRaw)
                ),
                pulse: tab.refreshPulse
            )
            .zIndex(4)

            chromeLayer

            Group {
                if let toast = tab.toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                        .padding(.top, topChromeHeight + 56)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .offset(y: -8)))
                        .allowsHitTesting(false)
                }
            }
            .motion(.pop, value: tab.toast)
            .zIndex(6)

            if holdKind != nil, !holdItems.isEmpty {
                holdRevealOverlay
            }

            if quickActionOpen, toolbarStyle == .quickAction {
                QuickActionFan(
                    anchor: quickActionFrame,
                    placement: addressBarPlacement,
                    theme: theme,
                    entries: quickActionEntries,
                    onDismiss: { withMotion(.fade, reduceMotion: reduceMotion) { quickActionOpen = false } }
                )
                .transition(.opacity)
                .zIndex(15)
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        // Light or dark status bar text to suit the page color. Only while Appearance is System; an explicit
        // Light or Dark choice is never overridden.
        .preferredColorScheme(appliedStatusBarScheme)
        .task(id: statusBarScheme) { await applyStatusBarScheme() }
        .onAppear { syncUnderPageColor() }
        .onChange(of: statusBarPlan.fill) { _, _ in syncUnderPageColor() }
        .background {
            // Reads the device bottom inset (home indicator) for the immersive layout.
            GeometryReader { geo in
                Color.clear.preference(key: HomeIndicatorInsetKey.self, value: geo.safeAreaInsets.bottom)
            }
        }
        .onPreferenceChange(HomeIndicatorInsetKey.self) { value in
            if let inset = ImmersiveLayout.homeIndicatorInset(fromSafeAreaBottom: value) {
                homeIndicatorInset = inset
            }
        }
        .onChange(of: tab.url) { _, url in
            if !addressFocused {
                address = url?.absoluteString ?? ""
                isEditingClassicAddress = false
            }
        }
        .onChange(of: browser.addressFocusRequest) { _, _ in focusAddressBarFromOutside() }
        .onChange(of: browser.burnConfirmRequest) { _, _ in confirmBurn = true }
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
                    withMotion(.bar, reduceMotion: reduceMotion) {
                        isEditingCompactAddress = false
                    }
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
            } else if toolbarStyle == .quickAction, !hasSeenQuickActionTip {
                chromeTipMessage = ChromeModeTips.quickActionMessage
            } else if addressBarPlacement == .top, !hasSeenTopBarTip {
                chromeTipMessage = ChromeModeTips.topBarMessage
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = tab.url { ActivityShareSheet(items: [url]) }
        }
        .flameConfirmation(isPresented: $confirmBurn, browser: browser)
        .alert("Open another app?", isPresented: Binding(
            get: { tab.externalURL != nil },
            set: { if !$0 { tab.externalURL = nil } }
        )) {
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
        .alert("Quick Action", isPresented: Binding(
            get: { chromeTipMessage == ChromeModeTips.quickActionMessage },
            set: { if !$0 { chromeTipMessage = nil; hasSeenQuickActionTip = true } }
        )) {
            Button("Got it") { chromeTipMessage = nil; hasSeenQuickActionTip = true }
        } message: {
            Text(ChromeModeTips.quickActionMessage)
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
            quickActionOpen = false
            if newValue == ToolbarStyle.compact.rawValue, !hasSeenCompactTip {
                chromeTipMessage = ChromeModeTips.compactMessage
            } else if newValue == ToolbarStyle.quickAction.rawValue, !hasSeenQuickActionTip {
                chromeTipMessage = ChromeModeTips.quickActionMessage
            }
        }
        .onChange(of: addressBarPlacementRaw) { _, newValue in
            quickActionOpen = false
            if newValue == AddressBarPlacement.top.rawValue, !hasSeenTopBarTip {
                chromeTipMessage = ChromeModeTips.topBarMessage
            }
        }
    }

    /// Floating chrome over the page. Empty space between the bars passes touches through to the page.
    private var chromeLayer: some View {
        VStack(spacing: 0) {
            if addressBarPlacement == .top {
                if immersiveLayout, !tab.hasPage {
                    // Light fade over the status bar only, above the floating capsule.
                    Color.clear
                        .frame(height: 0)
                        .background { statusBarScrim }
                }
            } else {
                // Keeps the status bar legible over full-screen pages when no bar sits at the top.
                Color.clear
                    .frame(height: 0)
                    .background { statusBarBackdrop }
            }
            // Everything stacked at the top: the app banner, then a top address bar. Its height is what content
            // insets measure.
            VStack(spacing: 0) {
                if let banner = visibleAppBanner {
                    AppBannerView(
                        info: banner,
                        accent: theme.primary,
                        onOpen: { openAppBanner(banner) },
                        onDismiss: { appBannerSession.dismiss(banner.hostKey, isPrivate: tab.isPrivate) }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if addressBarPlacement == .top {
                    topChrome
                        .padding(.top, immersiveLayout ? ImmersiveLayout.topGap : 0)
                        .solidHitArea(!immersiveLayout)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: visibleAppBanner)
            .background(ChromeHeightReader(key: TopChromeHeightKey.self))
            Spacer(minLength: 0)
            if let error = tab.errorMessage {
                errorBanner(error)
            }
            Group {
                if addressBarPlacement == .bottom {
                    bottomChrome
                } else if toolbarStyle == .classic {
                    classicNavOnly
                }
            }
            // Immersive: a slim gap under the floating capsule. Solid: the bar is pulled a little into the
            // home indicator area so the bezel under it is not so tall.
            .padding(.bottom, immersiveLayout ? ImmersiveLayout.bottomGap : -ImmersiveLayout.solidBottomPullDown)
            // Solid bars own their whole band. Floating controls only catch touches on themselves,
            // so the page stays live in the gaps between them.
            .solidHitArea(!immersiveLayout)
            .background(ChromeHeightReader(key: BottomChromeHeightKey.self))
        }
        // Immersive: the bar group runs to the physical bottom edge (the keyboard still lifts it).
        .ignoresSafeArea(.container, edges: immersiveLayout ? .bottom : [])
        .onPreferenceChange(TopChromeHeightKey.self) { topChromeHeight = $0 }
        .onPreferenceChange(BottomChromeHeightKey.self) { bottomChromeHeight = $0 }
    }

    private func errorBanner(_ error: String) -> some View {
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
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

    /// A thin strip on the right edge of the new tab page. Swiping in from it goes forward to the page this tab
    /// stepped back from. Only present when there is a page to go forward to.
    @ViewBuilder
    private var newTabForwardSwipe: some View {
        if swipeNavigationOn, tab.canGoForward {
            Color.clear
                .frame(width: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { value in
                            if EdgeSwipe.shouldCommit(translation: Double(value.translation.width), velocity: 0, side: .right) {
                                UISelectionFeedbackGenerator().selectionChanged()
                                tab.goForward()
                            }
                        }
                )
                .accessibilityHidden(true)
        }
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
        switch toolbarStyle {
        case .classic:
            classicAddressBlock(includeNav: false)
                .padding(.horizontal, immersiveLayout ? 12 : 18)
                .padding(.top, immersiveLayout ? 0 : 8)
                .padding(.bottom, immersiveLayout ? 6 : 8)
                .background { chromeScrim(edge: .top) }
        case .compact:
            compactToolbar
                .background { chromeScrim(edge: .top) }
        case .quickAction:
            quickActionToolbar
                .background { chromeScrim(edge: .top) }
        }
    }

    @ViewBuilder
    private var bottomChrome: some View {
        switch toolbarStyle {
        case .classic:
            classicToolbar
        case .compact:
            compactToolbar
                .background { chromeScrim(edge: .bottom) }
        case .quickAction:
            quickActionToolbar
                .background { chromeScrim(edge: .bottom) }
        }
    }

    private var classicToolbar: some View {
        VStack(spacing: 10) {
            classicAddressBlock(includeNav: true)
        }
        .padding(.horizontal, immersiveLayout ? 12 : 18)
        .padding(.top, immersiveLayout ? 0 : 10)
        .padding(.bottom, immersiveLayout ? 0 : 6)
        .background { chromeScrim(edge: .bottom) }
    }

    private var classicNavOnly: some View {
        VStack(spacing: 0) {
            classicNavRow
        }
        .padding(.horizontal, immersiveLayout ? 12 : 18)
        .padding(.top, immersiveLayout ? 0 : 8)
        .padding(.bottom, immersiveLayout ? 0 : 6)
        .background { chromeScrim(edge: .bottom) }
    }

    /// Live translucent band behind the chrome. It is one plain, unmasked material running full-bleed into
    /// the safe area, so the page keeps scrolling visibly underneath and the blur keeps updating.
    /// Earlier builds masked the material with a gradient and faded its opacity. Both force the system to
    /// render the blur in a separate pass that no longer follows the page, which made the bar look like a
    /// frozen picture. A light color wash (color only, no blur) keeps controls legible, and a hairline
    /// marks the edge. `extent` lets the band start a little beyond the controls.
    @ViewBuilder
    private func chromeScrim(edge: VerticalEdge, extent: CGFloat = 0) -> some View {
        if !immersiveLayout {
            solidChromeScrim(edge: edge, extent: extent)
        }
    }

    /// Status bar backdrop when no bar sits at the top. Immersive: a very light fade so status bar text
    /// stays readable over any page. Solid: the usual material band.
    @ViewBuilder
    private var statusBarBackdrop: some View {
        if immersiveLayout {
            // A page gets the painted strip instead (statusBarStrip). The new tab page keeps its wallpaper and
            // only gets the light fade.
            if !tab.hasPage {
                statusBarScrim
            }
        } else {
            solidChromeScrim(edge: .top, extent: 0)
        }
    }

    /// The status bar area in the immersive layout, painted with the page's own color so the clock sits on what
    /// looks like part of the page. Page content stops below it. The color change eases in.
    @ViewBuilder
    private var statusBarStrip: some View {
        switch statusBarPlan.fill {
        case .none:
            EmptyView()
        case .page(let color):
            statusStrip(fill: Color(red: color.red, green: color.green, blue: color.blue))
        case .fallback:
            statusStrip(fill: Color(uiColor: .systemBackground))
        }
    }

    private func statusStrip(fill: Color) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background { fill.ignoresSafeArea(.container, edges: .top) }
            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: statusBarPlan.fill)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var statusBarScheme: ColorScheme? {
        guard appearance == "System" else { return nil }
        switch statusBarPlan.schemeOverride {
        case .some(.dark): return .dark
        case .some(.light): return .light
        case .none: return nil
        }
    }

    /// Moves to the wanted status bar scheme at once when switching to or from "no override", and after a short wait
    /// when switching between light and dark. A newer wanted scheme cancels the wait.
    @MainActor
    private func applyStatusBarScheme() async {
        let target = statusBarScheme
        if target == nil || appliedStatusBarScheme == nil {
            appliedStatusBarScheme = target
            return
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        if Task.isCancelled { return }
        appliedStatusBarScheme = target
    }

    /// Past the edge of the page (rubber banding) the web view shows its under-page color. While the strip is
    /// painted that is the strip color, so the overscroll never shows a gap between the strip and the page.
    private func syncUnderPageColor() {
        if case .page(let color) = statusBarPlan.fill {
            tab.webView.underPageBackgroundColor = UIColor(
                red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1
            )
        } else {
            tab.webView.underPageBackgroundColor = .systemBackground
        }
    }

    /// Light gradient over the status bar area only. It follows light and dark so the clock and battery
    /// keep their contrast, and it fades to nothing so the page still shows through.
    private var statusBarScrim: some View {
        let base: Color = colorScheme == .dark ? .black : .white
        return LinearGradient(
            colors: [base.opacity(colorScheme == .dark ? 0.45 : 0.50), base.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(.container, edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func solidChromeScrim(edge: VerticalEdge, extent: CGFloat = 0) -> some View {
        let isDark = colorScheme == .dark
        let towardEdge = edge == .bottom
        let wash = LinearGradient(
            colors: [
                (isDark ? Color.black : Color.white).opacity(isDark ? 0.10 : 0.16),
                (isDark ? Color.black : Color.white).opacity(isDark ? 0.24 : 0.34)
            ],
            startPoint: towardEdge ? .top : .bottom,
            endPoint: towardEdge ? .bottom : .top
        )
        return ZStack(alignment: towardEdge ? .top : .bottom) {
            Rectangle().fill(.thinMaterial)
            wash
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 0.5)
        }
        .padding(towardEdge ? .top : .bottom, -extent)
        .ignoresSafeArea(.container, edges: towardEdge ? .bottom : .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func classicAddressBlock(includeNav: Bool) -> some View {
        VStack(spacing: 10) {
            if tab.isLoading {
                ProgressView(value: tab.progress).tint(theme.primary).accessibilityLabel("Page loading")
                    .motion(.progress, value: tab.progress)
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
            classicAddressLeading
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
                tab.reloadOrStop()
            } label: {
                Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                    .contentTransition(.symbolEffect(.replace))
                    .motion(.pop, value: tab.isLoading)
            }
            .accessibilityLabel(tab.isLoading ? "Stop loading" : "Reload")
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 16).padding(.trailing, 6).frame(minHeight: barSize(52))
        .modifier(ClassicAddressSurface(immersive: immersiveLayout, isDark: colorScheme == .dark))
        .contentShape(Capsule())
        .motion(.bar, value: addressFocused || isEditingClassicAddress)
        .onTapGesture {
            if !(addressFocused || isEditingClassicAddress) {
                beginClassicAddressEditing()
            }
        }
        // The width slider only narrows the resting bar; editing uses the full width.
        .searchBarWidth(addressFocused || isEditingClassicAddress ? SearchBarWidth.full : searchBarWidthValue)
    }

    /// Classic button row, built from the customizable toolbar layout.
    private var classicNavRow: some View {
        HStack {
            ForEach(Array(toolbarLayout.classic.enumerated()), id: \.element) { index, kind in
                if index > 0 {
                    Spacer()
                }
                classicItem(kind)
                    .modifier(FloatingCircle(
                        size: barSize(48),
                        active: immersiveLayout,
                        isDark: colorScheme == .dark
                    ))
            }
        }
    }

    @ViewBuilder
    private func classicItem(_ kind: ToolbarItemKind) -> some View {
        switch kind {
        case .back:
            holdNavButton(
                label: "Back",
                icon: "chevron.left",
                enabled: tab.canGoBack,
                kind: .back
            ) { tab.goBack() }
        case .forward:
            holdNavButton(
                label: "Forward",
                icon: "chevron.right",
                enabled: tab.canGoForward,
                kind: .forward
            ) { tab.goForward() }
        case .share:
            control("Share page", icon: "square.and.arrow.up") { showShare = true }.disabled(tab.url == nil)
        case .tabs:
            tabsButton
        case .menu:
            Button { sheet = .menu } label: {
                Image(systemName: immersiveLayout ? "ellipsis" : "ellipsis.circle").font(.title3)
                    .frame(minWidth: barSize(44), minHeight: barSize(44))
            }
            .accessibilityLabel("Browser menu")
        default:
            control(toolbarTitle(kind), icon: toolbarSymbol(kind)) { performToolbarItem(kind) }
                .disabled(!isToolbarItemEnabled(kind))
        }
    }

    // MARK: - Customizable toolbar items

    private func isToolbarItemEnabled(_ kind: ToolbarItemKind) -> Bool {
        switch kind {
        case .back: return tab.canGoBack
        case .forward: return tab.canGoForward
        case .reload, .reader, .find, .desktopSite, .pageZoom: return tab.hasPage
        case .share, .addBookmark: return tab.url != nil
        default: return true
        }
    }

    private func toolbarTitle(_ kind: ToolbarItemKind) -> String {
        switch kind {
        case .reload: return tab.isLoading ? "Stop" : kind.title
        case .reader: return tab.isReaderActive ? "Exit Reader" : kind.title
        case .desktopSite: return tab.prefersDesktopSite ? "Mobile Site" : kind.title
        default: return kind.title
        }
    }

    private func toolbarSymbol(_ kind: ToolbarItemKind) -> String {
        switch kind {
        case .reload: return tab.isLoading ? "xmark" : kind.symbolName
        case .desktopSite: return tab.prefersDesktopSite ? "iphone" : kind.symbolName
        default: return kind.symbolName
        }
    }

    private func performToolbarItem(_ kind: ToolbarItemKind) {
        switch kind {
        case .address: beginCompactAddressEditing()
        case .back: tab.goBack()
        case .forward: tab.goForward()
        case .reload:
            tab.reloadOrStop()
        case .share: showShare = true
        case .tabs: sheet = .tabs
        case .newTab: browser.addTab()
        case .bookmarks: sheet = .library
        case .addBookmark: browser.bookmark(tab)
        case .reader: tab.toggleReaderMode(dark: colorScheme == .dark)
        case .find: tab.findOnPage()
        case .desktopSite: tab.toggleDesktopSite()
        case .pageZoom: sheet = .pageZoom
        case .downloads: sheet = .downloads
        case .burn: confirmBurn = true
        case .menu: sheet = .menu
        }
    }

    @ViewBuilder
    private var classicAddressLeading: some View {
        if addressFocused || isEditingClassicAddress || !tab.hasPage {
            Image(systemName: tab.isPrivate ? "eye.slash" : "magnifyingglass")
                .foregroundStyle(.secondary)
        } else {
            connectionSecurityAffordance(font: .footnote, textFont: .caption.weight(.semibold))
        }
    }

    @ViewBuilder
    private func connectionSecurityAffordance(font: Font, textFont: Font) -> some View {
        let security = ConnectionSecurity.evaluate(
            url: tab.url,
            hasPage: tab.hasPage,
            hasOnlySecureContent: tab.hasOnlySecureContent
        )
        switch security {
        case .secure:
            Image(systemName: "lock.fill")
                .font(font)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Secure connection")
        case .notSecure:
            Text("Not Secure")
                .font(textFont)
                .foregroundStyle(.orange)
                .accessibilityLabel("Not Secure")
        case .none:
            EmptyView()
        }
    }

    /// The Search quick action: puts the cursor in whichever address bar this toolbar style has.
    private func focusAddressBarFromOutside() {
        guard !addressFocused else { return }
        switch toolbarStyle {
        case .compact: beginCompactAddressEditing()
        case .quickAction: beginQuickActionAddressEditing()
        case .classic: beginClassicAddressEditing()
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

    // MARK: - Quick Action chrome

    /// Quick Action: outlined search pill on the left, crimson center control, tabs button on the right.
    /// Both sides are equal-width containers so the center control stays centered.
    /// Tapping the center control fans out Back, Forward, Reload, Tabs, New Tab, and Share. Menu is a
    /// toolbar button beside Tabs (on the outer edge by default), placed by Customize Toolbar.
    /// Tapping the search pill, or pressing and holding the center control, opens address editing.
    private var quickActionToolbar: some View {
        VStack(spacing: 8) {
            if tab.isLoading {
                ProgressView(value: tab.progress).tint(theme.primary).padding(.horizontal, 24)
                    .motion(.progress, value: tab.progress)
            }
            if isEditingCompactAddress {
                // Reuse the Compact editing pill so focus, submit, and cancel behave the same.
                // The matched geometry lets the search pill grow into the full-width editor.
                compactPill
                    .matchedGeometryEffect(id: "quickActionAddress", in: addressNamespace)
                    .padding(.horizontal, immersiveLayout ? 12 : 16)
            } else {
                HStack(spacing: 12) {
                    quickActionSearchPill
                        .matchedGeometryEffect(id: "quickActionAddress", in: addressNamespace)
                        .searchBarWidth(searchBarWidthValue)
                        .frame(maxWidth: .infinity)
                    quickActionButton
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        ForEach(toolbarLayout.quickActionBar) { kind in
                            quickActionBarItem(kind)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, immersiveLayout ? 12 : 16)
            }
        }
        .padding(.top, immersiveLayout ? 0 : 6)
        .padding(.bottom, immersiveLayout ? 0 : 8)
    }

    /// Outlined search pill: clear fill with a faint accent tint, accent capsule stroke matching the
    /// tabs button, accent magnifier, and the host (with the lock or Not Secure indicator) or Search.
    /// Press and hold to peek the full page title and host without opening the editor.
    private var quickActionSearchPill: some View {
        Button {
            if suppressSearchTap {
                suppressSearchTap = false
                return
            }
            beginQuickActionAddressEditing()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.primary)
                if tab.hasPage {
                    connectionSecurityAffordance(font: .caption2, textFont: .caption2.weight(.semibold))
                }
                Text(AddressDisplay.quickActionPillLabel(title: compactTitle, url: tab.url, hasPage: tab.hasPage))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: barSize(36))
            .modifier(QuickActionPillSurface(immersive: immersiveLayout, tint: theme.primary))
            .overlay(Capsule(style: .continuous).stroke(theme.primary, lineWidth: 1.7))
            .frame(minHeight: barSize(44))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in showQuickActionPageInfo() }
        )
        .overlay(alignment: addressBarPlacement == .top ? .topLeading : .bottomLeading) {
            if showSearchPageInfo, tab.hasPage {
                quickActionPageInfoBubble
                    .offset(y: addressBarPlacement == .top ? 52 : -52)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: addressBarPlacement == .top ? .topLeading : .bottomLeading)))
            }
        }
        .accessibilityLabel("Search or enter address")
        .accessibilityValue(quickActionPageAccessibilityValue)
        .accessibilityHint("Opens the address field")
    }

    /// Current page for VoiceOver: title first, then host.
    private var quickActionPageAccessibilityValue: String {
        AddressDisplay.pageSummary(title: compactTitle, url: tab.url, hasPage: tab.hasPage)
    }

    private var quickActionPageInfoBubble: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(compactTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            if let host = AddressDisplay.friendlyHost(from: tab.url) {
                HStack(spacing: 4) {
                    connectionSecurityAffordance(font: .caption2, textFont: .caption2.weight(.semibold))
                    Text(host)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 230, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func showQuickActionPageInfo() {
        // On a new tab there is nothing to show, so let the tap open the editor as usual.
        guard tab.hasPage else { return }
        suppressSearchTap = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withMotion(.pop, reduceMotion: reduceMotion) { showSearchPageInfo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withMotion(.fade, reduceMotion: reduceMotion) { showSearchPageInfo = false }
            // The release after a hold may not reach the button (for example after sliding off).
            suppressSearchTap = false
        }
    }

    private var quickActionTabsButton: some View {
        Button { sheet = .tabs } label: {
            quickActionSideLabel {
                Text("\(browser.tabs.count)")
                    .font(.subheadline.bold())
            }
        }
        .accessibilityLabel("Tabs, \(browser.tabs.count) open")
        .contextMenu { tabsContextMenu }
    }

    @ViewBuilder
    private func quickActionBarItem(_ kind: ToolbarItemKind) -> some View {
        if kind == .tabs {
            quickActionTabsButton
        } else {
            Button { performToolbarItem(kind) } label: {
                Image(systemName: toolbarSymbol(kind))
                    .font(barIconFont)
                    .frame(width: barSize(44), height: barSize(44))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
            }
            .disabled(!isToolbarItemEnabled(kind))
            .accessibilityLabel(toolbarTitle(kind))
        }
    }

    /// Accent-outlined rounded square matching the Classic tabs button, on a faint material tile
    /// so it stays legible when floating over page content.
    private func quickActionSideLabel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: barSize(24), height: barSize(26))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(lineWidth: 1.7))
            .frame(width: barSize(44), height: barSize(44))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
    }

    private var quickActionButton: some View {
        QuickActionGlyph(theme: theme, isOpen: false, diameter: barSize(QuickActionGlyph.size))
            .opacity(quickActionOpen ? 0 : 1)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: QuickActionFrameKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(QuickActionFrameKey.self) { quickActionFrame = $0 }
            .onTapGesture { openQuickAction() }
            .onLongPressGesture(minimumDuration: 0.4) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                beginQuickActionAddressEditing()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Quick actions")
            .accessibilityHint(quickActionHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { openQuickAction() }
            .accessibilityAction(named: "Search or enter address") { beginQuickActionAddressEditing() }
    }

    private var quickActionHint: String {
        let titles = toolbarLayout.quickActionFan.map(\.title)
        return "Shows " + ListFormatter.localizedString(byJoining: titles)
    }

    private var quickActionEntries: [QuickActionEntry] {
        toolbarLayout.quickActionFan.map { item -> QuickActionEntry in
            switch item {
            case .back:
                return QuickActionEntry(
                    item: item,
                    enabled: tab.canGoBack,
                    action: { tab.goBack() },
                    onHold: { showQuickActionHistory(.back) }
                )
            case .forward:
                return QuickActionEntry(
                    item: item,
                    enabled: tab.canGoForward,
                    action: { tab.goForward() },
                    onHold: { showQuickActionHistory(.forward) }
                )
            case .reload:
                return QuickActionEntry(
                    item: item,
                    enabled: tab.hasPage,
                    titleOverride: tab.isLoading ? "Stop" : nil,
                    symbolOverride: tab.isLoading ? "xmark" : nil
                ) {
                    tab.reloadOrStop()
                }
            case .tabs:
                return QuickActionEntry(item: item, badge: "\(browser.tabs.count)") { sheet = .tabs }
            default:
                return QuickActionEntry(
                    item: item,
                    enabled: isToolbarItemEnabled(item),
                    titleOverride: toolbarTitle(item),
                    symbolOverride: toolbarSymbol(item)
                ) {
                    performToolbarItem(item)
                }
            }
        }
    }

    /// Press and hold Back or Forward in the fan: close the fan, then show the same history peek
    /// Classic and Compact use. Tap a page in the list to open it.
    private func showQuickActionHistory(_ kind: HoldRevealKind) {
        quickActionOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            beginHoldReveal(kind)
            // No Back or Forward button owns this touch, so do not swallow the next nav tap.
            suppressNextNavTap = false
        }
    }

    private func openQuickAction() {
        guard !quickActionOpen else { return }
        if addressFocused { addressFocused = false }
        withMotion(.fade, reduceMotion: reduceMotion) {
            quickActionOpen = true
        }
    }

    private func beginQuickActionAddressEditing() {
        quickActionOpen = false
        beginCompactAddressEditing()
    }

    private var compactToolbar: some View {
        VStack(spacing: 8) {
            if tab.isLoading {
                ProgressView(value: tab.progress).tint(theme.primary).padding(.horizontal, 24)
                    .motion(.progress, value: tab.progress)
            }
            HStack(spacing: 12) {
                // While editing, the side buttons slide away and the pill springs out to fill the row.
                if !isEditingCompactAddress, !toolbarLayout.compactLeading.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(toolbarLayout.compactLeading) { kind in
                            compactItem(kind)
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                compactPill
                    .searchBarWidth(isEditingCompactAddress ? SearchBarWidth.full : searchBarWidthValue)

                if !isEditingCompactAddress, !toolbarLayout.compactTrailing.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(toolbarLayout.compactTrailing) { kind in
                            compactItem(kind)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, immersiveLayout ? 12 : 16)
            .padding(.bottom, immersiveLayout ? 0 : 8)
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private func compactItem(_ kind: ToolbarItemKind) -> some View {
        switch kind {
        case .back:
            compactHoldCircle(
                icon: "chevron.left",
                enabled: tab.canGoBack,
                label: "Back",
                kind: .back
            ) { tab.goBack() }
        case .forward:
            compactHoldCircle(
                icon: "chevron.right",
                enabled: tab.canGoForward,
                label: "Forward",
                kind: .forward
            ) { tab.goForward() }
        case .share:
            compactCircle(icon: "square.and.arrow.up", enabled: tab.url != nil, label: "Share page") {
                showShare = true
            }
        case .tabs:
            compactCircle(icon: "square.on.square", enabled: true, label: "Tabs, \(browser.tabs.count) open") {
                sheet = .tabs
            }
            .contextMenu { tabsContextMenu }
        case .menu:
            compactCircle(icon: "ellipsis", enabled: true, label: "Browser menu") {
                sheet = .menu
            }
        default:
            compactCircle(icon: toolbarSymbol(kind), enabled: isToolbarItemEnabled(kind), label: toolbarTitle(kind)) {
                performToolbarItem(kind)
            }
        }
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
                // Tabs sits beside the pill when it is one of the bar buttons, so the pill does not repeat it.
                if !toolbarLayout.compact.contains(.tabs) {
                    tabsButtonCompact
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(compactTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if tab.hasPage {
                        HStack(spacing: 4) {
                            connectionSecurityAffordance(
                                font: .caption2,
                                textFont: .caption2.weight(.semibold)
                            )
                            if let host = CompactAddressChrome.hostSubtitle(url: tab.url, hasPage: tab.hasPage) {
                                Text(host)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                if tab.hasPage {
                    Button {
                        tab.reloadOrStop()
                    } label: {
                        Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .contentTransition(.symbolEffect(.replace))
                            .motion(.pop, value: tab.isLoading)
                    }
                    .accessibilityLabel(tab.isLoading ? "Stop loading" : "Reload")
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: barSize(48))
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
        withMotion(.bar, reduceMotion: reduceMotion) {
            isEditingCompactAddress = true
        }
        // Focus after the TextField is in the hierarchy.
        focusAddressFieldSelectingAll()
    }

    private func cancelCompactAddressEditing() {
        addressFocused = false
        withMotion(.bar, reduceMotion: reduceMotion) {
            isEditingCompactAddress = false
        }
        address = tab.url?.absoluteString ?? ""
    }

    private func submitAddress() {
        let engine = SearchEngine(rawValue: searchEngine) ?? SearchEngine.defaultEngine
        // Always resolve through AddressResolver so search stays inside Zalla's webview.
        guard let url = AddressResolver.resolve(address, engine: engine, customTemplate: customSearchTemplate) else { return }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        tab.load(url)
        addressFocused = false
        withMotion(.bar, reduceMotion: reduceMotion) {
            isEditingCompactAddress = false
        }
        isEditingClassicAddress = false
    }

    private func compactCircle(icon: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(barIconFont)
                .frame(width: barSize(44), height: barSize(44))
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
            .font(barIconFont)
            // Accent when there is somewhere to go, like the other bar buttons; dim when not.
            .foregroundStyle(enabled ? theme.primary : Color.primary)
            .frame(width: barSize(48), height: barSize(48))
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
                .frame(minWidth: barSize(44), minHeight: barSize(44))
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
    }

    @ViewBuilder
    private var tabsContextMenu: some View {
        Button {
            browser.addTab()
            sheet = nil
        } label: { Label("New Tab", systemImage: "plus") }
        Button {
            sheet = nil
            Task { await browser.openPrivateTab() }
        } label: { Label("New Private Tab", systemImage: "eye.slash") }
        Divider()
        Button { sheet = .library } label: { Label("Bookmarks", systemImage: "book") }
        Button { sheet = .downloads } label: { Label("Downloads", systemImage: "arrow.down.circle") }
        Button { sheet = .tabs } label: { Label("All Tabs", systemImage: "square.on.square") }
    }

    private func holdNavButton(label: String, icon: String, enabled: Bool, kind: HoldRevealKind, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .foregroundStyle(enabled ? theme.primary : Color.primary)
            .frame(minWidth: barSize(52), minHeight: barSize(52))
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
        Button(action: action) { Image(systemName: icon).frame(minWidth: barSize(44), minHeight: barSize(44)) }
            .accessibilityLabel(label)
    }
}

private struct TopChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct BottomChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Reports the laid-out height of a chrome bar (its safe-area bleed is not included).
private struct ChromeHeightReader<Key: PreferenceKey>: View where Key.Value == CGFloat {
    let key: Key.Type

    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: key, value: geo.size.height)
        }
    }
}

extension View {
    /// Solid bars own their whole band for touches. Floating controls catch touches only on themselves.
    @ViewBuilder
    fileprivate func solidHitArea(_ solid: Bool) -> some View {
        if solid {
            contentShape(Rectangle())
        } else {
            self
        }
    }
}

/// Immersive layout: one control floating on its own glass circle over the page.
private struct FloatingCircle: ViewModifier {
    let size: CGFloat
    let active: Bool
    let isDark: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            content
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(isDark ? 0.16 : 0.10), lineWidth: 0.75))
                .shadow(color: .black.opacity(isDark ? 0.35 : 0.16), radius: 10, y: 3)
        } else {
            content
        }
    }
}

/// The Classic address field: a solid grouped capsule, or its own floating glass capsule when immersive.
private struct ClassicAddressSurface: ViewModifier {
    let immersive: Bool
    let isDark: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if immersive {
            content
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).strokeBorder(Color.primary.opacity(isDark ? 0.16 : 0.10), lineWidth: 0.75))
                .shadow(color: .black.opacity(isDark ? 0.35 : 0.16), radius: 10, y: 3)
        } else {
            content
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule(style: .continuous))
        }
    }
}

/// The Quick Action search pill: a faint accent tint, plus glass behind it when floating over the page.
private struct QuickActionPillSurface: ViewModifier {
    let immersive: Bool
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if immersive {
            content
                .background(tint.opacity(0.08), in: Capsule(style: .continuous))
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
        } else {
            content
                .background(tint.opacity(0.08), in: Capsule(style: .continuous))
        }
    }
}

/// Reports the device safe area bottom (home indicator) to the immersive layout.
private struct HomeIndicatorInsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
    /// Heights of the floating chrome over the page, not counting the device safe area.
    var chromeInsets: UIEdgeInsets = .zero

    func makeUIView(context: Context) -> WKWebView {
        // Every time a tab is shown, make sure its edge swipes are in place and match the Settings switch.
        EdgeNavigation.install(on: webView, enabled: SwipeNavigation.isEnabled)
        Self.apply(chromeInsets, to: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        Self.apply(chromeInsets, to: uiView)
    }

    /// Lets pages scroll fully clear of the translucent chrome. The scroll view keeps its automatic
    /// adjustment, which adds whichever notch and home indicator insets the web view frame overlaps (none at the
    /// top while the status bar strip is painted, since the frame then starts below it), so only the bar heights
    /// are added here.
    private static func apply(_ insets: UIEdgeInsets, to webView: WKWebView) {
        let scrollView = webView.scrollView
        // While the pull to refresh spinner is out, UIKit owns the top inset.
        if scrollView.refreshControl?.isRefreshing == true { return }
        guard scrollView.contentInset != insets else { return }
        let wasAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 1
        scrollView.contentInset = insets
        scrollView.verticalScrollIndicatorInsets = insets
        if wasAtTop {
            // Keep the top of the page just below the top bar instead of hidden under it.
            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
        }
    }
}

private struct BrowserMenuSheet: View {
    @ObservedObject var browser: BrowserStore
    @Binding var sheet: BrowserSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShare = false
    @State private var confirmFlame = false
    @AppStorage(MenuTopRow.storageKey) private var menuTopRowData = Data()

    var body: some View {
        List {
            if let tab = browser.selected {
                // Customize it in Settings, Appearance. Every action here also lives further down the Menu.
                MenuNavigationRow(
                    tab: tab,
                    items: MenuTopRow.decode(menuTopRowData).items,
                    onAction: { performTopRowAction($0, tab: tab) },
                    onDone: { dismiss() }
                )
            }
            Section("Page actions") {
                Button {
                    browser.addTab()
                    dismiss()
                } label: { Label("New tab", systemImage: "plus") }
                Button {
                    dismiss()
                    Task { await browser.openPrivateTab() }
                } label: { Label("New private tab", systemImage: "eye.slash") }
                Button {
                    let tab = browser.selected
                    dismiss()
                    // The find bar needs the page, not the sheet, to take focus.
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 450_000_000)
                        tab?.findOnPage()
                    }
                } label: { Label("Find on page", systemImage: "text.magnifyingglass") }
                .disabled(!(browser.selected?.hasPage ?? false))
                Button {
                    browser.selected?.toggleDesktopSite()
                    dismiss()
                } label: {
                    HStack {
                        Label("Request Desktop Site", systemImage: "desktopcomputer")
                        Spacer()
                        if browser.selected?.prefersDesktopSite == true {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                .disabled(!(browser.selected?.hasPage ?? false))
                .accessibilityValue(browser.selected?.prefersDesktopSite == true ? "On" : "Off")
                if let tab = browser.selected, tab.hasPage {
                    PageZoomControl(tab: tab)
                    VideoSaverMenuRow(tab: tab, browser: browser, sheet: $sheet)
                    SiteBlockingMenuRows(tab: tab, onDone: { dismiss() })
                    SiteToolsMenuRows(tab: tab)
                    NavigationLink {
                        PrivacyReportView(tab: tab)
                    } label: {
                        Label("Privacy report", systemImage: "checklist")
                    }
                }
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
                if let tab = browser.selected {
                    ListenMenuRows(tab: tab, speaker: browser.speaker, onDone: { dismiss() })
                }
                Button {
                    if let tab = browser.selected { browser.bookmark(tab) }
                    dismiss()
                } label: { Label("Bookmark page", systemImage: "bookmark") }
                .disabled(browser.selected?.url == nil)
                Button {
                    showShare = true
                } label: { Label("Share", systemImage: "square.and.arrow.up") }
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
            Section {
                Button(role: .destructive) {
                    confirmFlame = true
                } label: {
                    Label { Text("Burn It All") } icon: { FlameMark(size: 22) }
                }
            } footer: {
                Text("Closes every tab, erases history, cookies, and site data, then closes Zalla.")
            }
        }
        .flameConfirmation(isPresented: $confirmFlame, browser: browser, onBurn: { dismiss() })
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .sheet(isPresented: $showShare) {
            if let url = browser.selected?.url {
                ActivityShareSheet(items: [url])
            }
        }
    }

    /// Back, Forward, and Reload run inside the row. Everything else lands here.
    private func performTopRowAction(_ item: MenuTopRowItem, tab: BrowserTab) {
        switch item {
        case .back, .forward, .reload:
            break
        case .tabs:
            sheet = .tabs
        case .settings:
            sheet = .settings
        case .downloads:
            sheet = .downloads
        case .share:
            showShare = true
        case .bookmark:
            browser.bookmark(tab)
            dismiss()
        case .find:
            dismiss()
            // The find bar needs the page, not the sheet, to take focus.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                tab.findOnPage()
            }
        case .newTab:
            browser.addTab()
            dismiss()
        case .home:
            tab.goHome()
            dismiss()
        case .burn:
            confirmFlame = true
        }
    }
}

/// The customizable top row of the menu sheet. Default: Back, Forward, Reload, Share, Settings.
private struct MenuNavigationRow: View {
    @ObservedObject var tab: BrowserTab
    let items: [MenuTopRowItem]
    let onAction: (MenuTopRowItem) -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                cell(item)
            }
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func cell(_ item: MenuTopRowItem) -> some View {
        switch item {
        case .back:
            navButton("Back", icon: item.symbolName, enabled: tab.canGoBack) {
                tab.goBack()
                onDone()
            }
        case .forward:
            navButton("Forward", icon: item.symbolName, enabled: tab.canGoForward) {
                tab.goForward()
                onDone()
            }
        case .reload:
            navButton(tab.isLoading ? "Stop" : "Reload", icon: tab.isLoading ? "xmark" : item.symbolName, enabled: tab.hasPage) {
                tab.reloadOrStop()
                onDone()
            }
        case .share, .bookmark:
            navButton(item.shortTitle, icon: item.symbolName, enabled: tab.url != nil) { onAction(item) }
        case .find, .home:
            navButton(item.shortTitle, icon: item.symbolName, enabled: tab.hasPage) { onAction(item) }
        case .tabs, .settings, .newTab, .burn, .downloads:
            navButton(item.shortTitle, icon: item.symbolName, enabled: true) { onAction(item) }
        }
    }

    private func navButton(_ title: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

/// Minus, current percent, plus, and reset for the page zoom of the current site.
private struct PageZoomControl: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        HStack(spacing: 12) {
            Label("Page zoom", systemImage: "textformat.size")
            Spacer(minLength: 8)
            Button {
                tab.setPageZoom(PageZoom.previous(before: tab.pageZoom))
            } label: {
                Image(systemName: "minus")
                    .frame(width: 32, height: 32)
            }
            .disabled(tab.pageZoom <= PageZoom.minimum + 0.001)
            .accessibilityLabel("Zoom out")
            Button {
                tab.setPageZoom(PageZoom.defaultLevel)
            } label: {
                Text(PageZoom.percentText(tab.pageZoom))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 52)
            }
            .accessibilityLabel("Reset zoom, now \(PageZoom.percentText(tab.pageZoom))")
            Button {
                tab.setPageZoom(PageZoom.next(after: tab.pageZoom))
            } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
            }
            .disabled(tab.pageZoom >= PageZoom.maximum - 0.001)
            .accessibilityLabel("Zoom in")
        }
        .buttonStyle(.borderless)
    }
}

/// Small sheet opened from the toolbar Page Zoom button.
private struct PageZoomSheet: View {
    @ObservedObject var tab: BrowserTab
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                PageZoomControl(tab: tab)
                Button("Reset to 100%") {
                    tab.setPageZoom(PageZoom.defaultLevel)
                }
                .disabled(PageZoom.isDefault(tab.pageZoom))
            } footer: {
                Text(tab.isPrivate
                    ? "Private tabs keep this zoom only until the tab closes."
                    : "Zalla remembers this zoom for \(PageZoom.hostKey(for: tab.url) ?? "this site").")
            }
        }
        .navigationTitle("Page Zoom")
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
    @ObservedObject private var unlock = ZallaUnlock.shared
    /// Group chosen in the chip bar; nil shows every tab.
    @State private var groupFilter: UUID?
    @State private var showGroupEditor = false
    @State private var editingGroup: TabGroup?
    /// Tab waiting to join a group that is being created from its menu.
    @State private var tabForNewGroup: BrowserTab?
    @State private var showUpsell = false
    @State private var confirmFlame = false

    private let columns = [GridItem(.adaptive(minimum: 156), spacing: 16)]

    /// Tabs shown in the grid: hides private tabs while they are locked, and applies the group filter.
    private var visibleTabs: [BrowserTab] {
        browser.tabs.filter { tab in
            if tab.isPrivate, browser.privateLocked { return false }
            guard unlock.isUnlocked, let groupFilter else { return true }
            return tab.groupID == groupFilter
        }
    }

    var body: some View {
        ScrollView {
            groupBar
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(visibleTabs) { tab in
                    TabPreviewCard(
                        tab: tab,
                        browser: browser,
                        showsGroups: unlock.isUnlocked,
                        onNewGroup: {
                            tabForNewGroup = tab
                            editingGroup = nil
                            showGroupEditor = true
                        },
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
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .motion(.card, value: browser.tabs.map(\.id))
        }
        .sheet(isPresented: $showGroupEditor) {
            TabGroupEditor(browser: browser, group: editingGroup, onCreated: { created in
                if let tab = tabForNewGroup { browser.assign(tab, to: created) }
                tabForNewGroup = nil
            })
        }
        .sheet(isPresented: $showUpsell) { ZallaUnlockSheet() }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Your tabs")
        .safeAreaInset(edge: .bottom) {
            Group {
                if showUndoClose, let undoClose {
                    HStack {
                        Text("Tab closed")
                            .font(.subheadline)
                        Spacer()
                        Button("Undo") {
                            if undoClose.isPrivate {
                                let url = undoClose.url
                                Task { await browser.openPrivateTab(url: url) }
                            } else {
                                browser.addTab(url: undoClose.url)
                            }
                            showUndoClose = false
                            self.undoClose = nil
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            showUndoClose = false
                        }
                    }
                }
            }
            .motion(.bar, value: showUndoClose)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu("New tab", systemImage: "plus") {
                    Button("Regular tab") {
                        let tab = browser.addTab()
                        if unlock.isUnlocked, let group = browser.groups.first(where: { $0.id == groupFilter }) {
                            browser.assign(tab, to: group)
                        }
                        dismiss()
                    }
                    Button("Private tab") {
                        dismiss()
                        Task { await browser.openPrivateTab() }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if browser.tabs.count > 1 {
                    Button("Close All", role: .destructive) { confirmCloseAll = true }
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    confirmFlame = true
                } label: {
                    Label { Text("Burn It All") } icon: { FlameMark(size: 22) }
                }
                .accessibilityHint("Erases tabs, history, cookies, and site data, then closes Zalla")
            }
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .flameConfirmation(isPresented: $confirmFlame, browser: browser, onBurn: { dismiss() })
        .alert("Close all tabs?", isPresented: $confirmCloseAll) {
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

private extension TabsView {
    /// Group chips for Zalla Unlock. Without it, one quiet row explains the feature.
    @ViewBuilder var groupBar: some View {
        if unlock.isUnlocked {
            TabGroupBar(
                browser: browser,
                filter: $groupFilter,
                onNewGroup: {
                    tabForNewGroup = nil
                    editingGroup = nil
                    showGroupEditor = true
                },
                onEdit: { group in
                    editingGroup = group
                    showGroupEditor = true
                }
            )
            .padding(.top, 10)
            .onChange(of: browser.groups) { _, groups in
                if let groupFilter, !groups.contains(where: { $0.id == groupFilter }) { self.groupFilter = nil }
            }
        } else {
            Button {
                showUpsell = true
            } label: {
                Label("Tab groups", systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }
}

private struct TabPreviewCard: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var browser: BrowserStore
    let showsGroups: Bool
    let onNewGroup: () -> Void
    let selected: Bool
    let select: () -> Void
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far the card is dragged sideways while a swipe is in progress.
    @State private var dragX: CGFloat = 0

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
                    if tab.isSleeping {
                        Image(systemName: "moon.zzz.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Sleeping")
                    }
                    if showsGroups, let group = browser.group(for: tab) {
                        Circle().fill(group.color.color).frame(width: 9, height: 9)
                            .accessibilityLabel("Group \(group.name)")
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
        .offset(x: dragX)
        .opacity(1 - 0.4 * CardSwipe.progress(translation: Double(dragX)))
        .onTapGesture(perform: select)
        .gesture(
            DragGesture(minimumDistance: CGFloat(CardSwipe.startDistance), coordinateSpace: .global)
                .onChanged { value in
                    // The card follows the finger sideways, like a card in Safari's tab view.
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragX = CGFloat(CardSwipe.followOffset(translation: Double(value.translation.width)))
                }
                .onEnded { value in
                    if CardSwipe.shouldClose(
                        translationX: Double(value.translation.width),
                        translationY: Double(value.translation.height),
                        predictedX: Double(value.predictedEndTranslation.width)
                    ) {
                        close()
                        // If the card stays (the last tab is replaced in place), it comes back to rest.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withMotion(.card, reduceMotion: reduceMotion) { dragX = 0 }
                        }
                    } else {
                        // A swipe that did not go far enough springs back.
                        withMotion(.card, reduceMotion: reduceMotion) { dragX = 0 }
                    }
                }
        )
        .contextMenu {
            if showsGroups {
                TabGroupMenu(browser: browser, tab: tab, onNewGroup: onNewGroup)
            }
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
                    } label: { Label("Import bookmarks from Safari or Chrome", systemImage: "square.and.arrow.down") }
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
        .motion(.fade, value: history)
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
                guard let text = BookmarkHTML.text(from: try Data(contentsOf: url)) else {
                    message = "That file could not be read as text. Export bookmarks as HTML from Safari or Chrome and try again."
                    return
                }
                Task { @MainActor in
                    let pages = await BookmarkHTML.parseInBackground(text)
                    let added = browser.importBookmarks(pages)
                    message = added == 0
                        ? "No new bookmarks were found in that file. Zalla reads the HTML file that Safari, Chrome, and Firefox export."
                        : "Imported \(added) bookmark\(added == 1 ? "" : "s")."
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

private struct DownloadsView: View {
    @ObservedObject var browser: BrowserStore
    /// Off when pushed from Settings, where Done would only step back and the Back button does that already.
    var showsDone = true
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var previewURL: URL?
    @State private var confirmClear = false

    var body: some View {
        List {
            if browser.downloads.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Nothing downloaded yet.")
                        .font(.headline)
                    Text("Files you save from the web land here, ready to open or share.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .listRowBackground(Color.clear)
            }
            ForEach(browser.downloads) { record in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: record.symbolName)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text(record.filename).font(.subheadline.weight(.semibold)).lineLimit(1)
                        if record.isPrivate {
                            Text("Private")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                        if record.state == .downloading {
                            ProgressView()
                                .controlSize(.small)
                        }
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
                                previewURL = fileURL
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
                        if let reason = record.errorMessage, !reason.isEmpty {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if showsDone { Button("Done") { dismiss() } }
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ActivityShareSheet(items: [shareURL])
            }
        }
        .quickLookPreview($previewURL)
        .alert("Clear all downloads?", isPresented: $confirmClear) {
            Button("Clear all", role: .destructive) { browser.clearAllDownloads() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func stateLabel(_ state: DownloadState) -> String {
        switch state {
        case .downloading: return "Downloading"
        case .completed: return "Done"
        case .failed: return "Did not finish"
        }
    }
}

private struct HomePersonalizationView: View {
    @AppStorage(HomeShortcuts.washIntensityKey) private var washIntensity = 0.35
    @AppStorage(HomeShortcuts.showLogoKey) private var showLogo = true
    @AppStorage(LogoStyle.storageKey) private var logoStyleRaw = LogoStyle.auto.rawValue
    @AppStorage(HomeWelcomeMode.storageKey) private var welcomeModeRaw = HomeWelcomeMode.quotes.rawValue
    @AppStorage(HomeWelcomeMode.userNameKey) private var userName = ""
    @AppStorage(HomeShortcuts.showSliderKey) private var showSlider = true
    @AppStorage(HomeShortcuts.showRecentHistoryKey) private var showRecentHistory = true
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Home slider", isOn: $showSlider)
                Toggle("Recently visited", isOn: $showRecentHistory)
                    .disabled(!showSlider)
            } header: {
                Text("Widgets")
            } footer: {
                Text("Swipe the top of a new tab to see your open tabs and recent pages. Widgets only use what is already saved on this device. Recent pages never appear in private tabs.")
            }
            Section("New tab") {
                Toggle("Show Zalla logo", isOn: $showLogo)
                if showLogo {
                    Picker("Logo style", selection: $logoStyleRaw) {
                        ForEach(LogoStyle.allCases) { style in
                            Text(style.rawValue).tag(style.rawValue)
                        }
                    }
                }
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
                Button("Reset the new tab page", role: .destructive) { confirmReset = true }
            } footer: {
                Text("Shortcuts themselves are edited from the pencil on the new tab page. Reset removes all your shortcuts and puts these settings back. Logo style Auto picks the red, white, or black logo that stands out on your background.")
            }
        }
        .navigationTitle("Home")
        .alert("Reset the new tab page?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                HomeShortcuts.resetToDefaults()
                welcomeModeRaw = HomeWelcomeMode.quotes.rawValue
                logoStyleRaw = LogoStyle.auto.rawValue
                userName = ""
                showSlider = true
                showRecentHistory = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every shortcut and restores the default welcome and widgets.")
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"
    @AppStorage("customAccentGradient") private var customAccentGradient = true
    @AppStorage("appIconPreference") private var appIconPreference = AppIconPreference.default.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @AppStorage(AddressBarPlacement.storageKey) private var addressBarPlacementRaw = AddressBarPlacement.bottom.rawValue
    @AppStorage(ImmersiveLayout.storageKey) private var immersiveLayout = ImmersiveLayout.defaultEnabled
    @AppStorage(PageColor.storageKey) private var statusBarMatchesPage = PageColor.defaultEnabled
    @AppStorage(SettingsTabHaptics.storageKey) private var settingsTabHaptics = SettingsTabHaptics.defaultEnabled
    @AppStorage(HTTPSOnly.storageKey) private var httpsOnlyMode = true
    @AppStorage(BurnEffectPlan.animationKey) private var burnAnimation = true
    @AppStorage(TabSleep.storageKey) private var sleepUnusedTabs = true
    @AppStorage(SwipeNavigation.storageKey) private var swipeNavigation = true
    @AppStorage(PullToRefresh.storageKey) private var pullToRefresh = true
    @AppStorage(QuickAction.storageKey) private var quickActionsOn = QuickAction.defaultEnabled
    @AppStorage(VideoSaver.storageKey) private var videoSaverOn = VideoSaver.defaultEnabled
    @AppStorage(CookieBannerDismiss.storageKey) private var cookieBanners = true
    @AppStorage(AppBanner.storageKey) private var appBanners = AppBanner.defaultEnabled
    @AppStorage(WebsiteLocation.modeKey) private var websiteLocationRaw = WebsiteLocationMode.ask.rawValue
    @AppStorage(SettingsCategory.storageKey) private var selectedCategory = SettingsCategory.default.rawValue
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
    @State private var showThemeUpsell = false
    @AppStorage(QuickTheme.storageKey) private var quickThemeFullLook = QuickTheme.defaultEnabled
    @AppStorage(NewTabBackground.storageKey) private var newTabBackgroundRaw = NewTabBackground.standard.storageValue
    @AppStorage(ThemePacks.transitionsKey) private var themeTransitionsOn = true
    @AppStorage(ThemeTransitionSpeed.storageKey) private var themeTransitionSpeedRaw = ThemeTransitionSpeed.normal.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var quickThemeKind: ThemeTransitionKind = .jungle
    @State private var quickThemePulse = 0
    @ObservedObject private var unlock = ZallaUnlock.shared
    @Environment(\.colorScheme) private var colorScheme

    private var quickThemePlan: ThemeTransitionPlan? {
        ThemeTransitionPlan.make(
            kind: quickThemeKind, unlocked: unlock.isUnlocked, enabled: themeTransitionsOn,
            reduceMotion: reduceMotion, speed: ThemeTransitionSpeed(stored: themeTransitionSpeedRaw)
        )
    }

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
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "29"
        return "\(marketing) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabStrip(selection: categoryBinding, accent: theme.primary)
            Divider()
            // Swipe sideways or tap a tab. Each page is its own Form, so the sections keep their normal look.
            TabView(selection: categoryBinding) {
                ForEach(SettingsCategory.allCases) { category in
                    Form { content(for: category) }
                        // Rows revealed by a switch (the custom accent controls) ease in instead of popping.
                        .motion(.bar, value: useCustomAccent)
                        .motion(.fade, value: iconMessage)
                        .tag(category)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Settings")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .alert("Clear browsing data and close all tabs?", isPresented: $confirmClear) {
            Button("Clear browsing data", role: .destructive) {
                Task { await browser.clearBrowsingData(); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Reset the App? Bookmarks are kept.", isPresented: $confirmReset) {
            Button("Reset the App", role: .destructive) {
                Task {
                    await browser.resetApp(keepingBookmarks: true)
                    hasCompletedOnboarding = false
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Use a matching app icon?",
            isPresented: Binding(
                get: { suggestIconForTheme != nil },
                set: { if !$0 { suggestIconForTheme = nil } }
            )
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
        .sheet(isPresented: $showThemeUpsell) { ZallaUnlockSheet() }
        .overlay {
            // Plays the theme's transition when a swatch applies it, like Apply in Theme packs.
            ThemeTransitionOverlay(plan: quickThemePlan, pulse: quickThemePulse)
        }
        .tint(theme.primary)
        .onAppear { loadCustomControls() }
    }

    private var categoryBinding: Binding<SettingsCategory> {
        Binding(
            get: { SettingsCategory.stored(selectedCategory) },
            set: { selectedCategory = $0.rawValue }
        )
    }

    @ViewBuilder
    private func content(for category: SettingsCategory) -> some View {
        switch category {
        case .appearance: appearanceTab
        case .privacy: privacyTab
        case .browsing: browsingTab
        case .tools: toolsTab
        case .premium: premiumTab
        case .about: aboutTab
        }
    }

    @ViewBuilder
    private var appearanceTab: some View {
        Group {
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
                Toggle("Immersive layout", isOn: $immersiveLayout)
                Toggle("Status bar matches the page", isOn: $statusBarMatchesPage)
                    .disabled(!immersiveLayout)
                Toggle("Haptic tap on Settings tabs", isOn: $settingsTabHaptics)
                NavigationLink("Customize Toolbar") {
                    ToolbarEditorView(theme: theme)
                }
                NavigationLink("Customize Menu Row") {
                    MenuTopRowEditorView(theme: theme)
                }
                NavigationLink("Home personalization") {
                    HomePersonalizationView()
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Classic toolbar with a bottom address bar is the default. Compact, Quick Action, and Top bar are optional. Quick Action keeps one center button that opens every control. Immersive layout lets pages run edge to edge with each control floating over the page on its own glass capsule or circle, like Safari. Turn it off for solid bars. With Immersive layout on, the status bar area takes the page's own color and page content stops below it; Status bar matches the page turns that coloring off.")
            }

            Section {
                ChromeStylePreview(
                    style: ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic,
                    placement: AddressBarPlacement(rawValue: addressBarPlacementRaw) ?? .bottom,
                    isDark: previewIsDark,
                    theme: theme
                )
                .padding(.vertical, 6)
                themeRow(title: "Quick theme", ids: ZallaThemeID.featured)
                NavigationLink {
                    ThemePacksView()
                } label: {
                    Label("Explore theme packs", systemImage: "sparkles")
                }
                Toggle("Themes apply the full look", isOn: $quickThemeFullLook)
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
                Text("Theme and accent")
            } footer: {
                Text("Tap a theme to apply it: the accent, and for a theme pack also its app icon, new tab background, and refresh transition. Jungle, Volcano, Deep Ocean, Retro Arcade, Neon City, Arctic, and Cherry Blossom need Zalla Unlock, and so does the full Space look. Themes are optional, and turning off Themes apply the full look makes a tap set the accent only. Zalla Red remains the default. Custom colors map to the closest matching accent icon.")
            }

            Section {
                iconGrid
                .onChange(of: appIconPreference) { _, newValue in
                    applyIcon(AppIconPreference(rawValue: newValue) ?? .default)
                }
                if let iconMessage {
                    Text(iconMessage).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("App icon")
            } footer: {
                Text("Every accent has a matching icon, plus Dark and Tinted.")
            }
        }
    }

    @ViewBuilder
    private var privacyTab: some View {
        Group {
            Section {
                NavigationLink("Content Blocking") {
                    ContentBlockingView()
                }
                NavigationLink("Privacy Shield") {
                    PrivacyShieldView()
                }
                if let tab = browser.selected {
                    NavigationLink("Privacy report") {
                        PrivacyReportView(tab: tab)
                    }
                }
                Toggle("Close cookie banners", isOn: $cookieBanners)
                NavigationLink("Location") {
                    LocationSettingsView()
                }
                Picker("Website location", selection: $websiteLocationRaw) {
                    ForEach(WebsiteLocationMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .onChange(of: websiteLocationRaw) { _, _ in
                    NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
                }
                Toggle("HTTPS-Only Mode", isOn: $httpsOnlyMode)
                Toggle("Burn It All fire effect", isOn: $burnAnimation)
                Button("Clear browsing data", role: .destructive) { confirmClear = true }
                    .disabled(browser.clearingData)
                Button("Reset the App", role: .destructive) { confirmReset = true }
                    .disabled(browser.clearingData)
                DisclosureGroup("What these do") {
                    Text("Content Blocking stops trackers and common ads on this device. Privacy Shield cleans tracking tags from links, trims referrers, and can add fingerprinting protection, encrypted lookups for Zalla's own requests, and a proxy you set up. Location is an optional city you type in, kept on this device. Website location decides whether sites may ask for your real location: Ask lets you choose each time, Never blocks every request. Your location goes only to a site you allow, never to Zalla, and private tabs ask every time. HTTPS-Only Mode opens websites over secure connections and asks before loading a site that does not support one. Close cookie banners picks the reject or necessary-only button for you, and never presses accept. The privacy report shows what Zalla did for you, and it stays on this device. Clear browsing data closes all tabs and removes history, cookies, website caches, and saved page zoom levels. Bookmarks and downloads are kept. Burn It All plays a fire effect before it closes Zalla; turn the fire effect off for a quick fade instead. Face ID for private tabs and Auto-clear are part of Zalla Unlock, and live in the Premium tab. Reset the App also restores appearance, search engine, theme, icon preference, toolbar style and layout, address bar placement, HTTPS-Only Mode, content blocking settings and rules, Privacy Shield, location and website location, site CSS, tab groups, Face ID and auto-clear settings, home shortcuts, and onboarding, clears downloads, and keeps bookmarks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Privacy")
            }
        }
    }

    @ViewBuilder
    private var browsingTab: some View {
        Group {
            Section {
                SearchEngineSettingsRows()
                Button {
                    showImporter = true
                } label: { Label("Import bookmarks from Safari or Chrome", systemImage: "square.and.arrow.down") }
                Toggle("Sleep unused tabs", isOn: $sleepUnusedTabs)
                Toggle("Swipe from edges to go back", isOn: $swipeNavigation)
                    .onChange(of: swipeNavigation) { _, newValue in
                        browser.tabs.forEach { $0.setSwipeNavigation(newValue) }
                    }
                Toggle("Pull down to refresh", isOn: $pullToRefresh)
                    .onChange(of: pullToRefresh) { _, newValue in
                        browser.tabs.forEach { $0.setPullToRefresh(newValue) }
                    }
                Toggle("App banners", isOn: $appBanners)
                Button {
                    exportBookmarks()
                } label: { Label("Export bookmarks", systemImage: "square.and.arrow.up") }
                .disabled(browser.bookmarks.isEmpty)
            } header: {
                Text("Browsing")
            } footer: {
                Text("Tabs you have not opened for a while unload their page to save memory and battery. They reload when you open them. Edge swipes go back and forward, like Safari. Pull down at the top of a page to reload it. App banners show a slim Open in the app bar when a site says it has an app; Open only tries the app if it is installed and never goes to the App Store.")
            }
        }
    }

    @ViewBuilder
    private var toolsTab: some View {
        Group {
            Section("Tools") {
                NavigationLink {
                    HowToListView()
                } label: {
                    Label("How to", systemImage: "questionmark.bubble")
                }
                NavigationLink {
                    NetworkSpeedView()
                } label: {
                    Label("Network Speed", systemImage: "gauge.with.dots.needle.67percent")
                }
                NavigationLink {
                    DownloadsView(browser: browser, showsDone: false)
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                NavigationLink {
                    WidgetsSettingsView(browser: browser)
                } label: {
                    Label("Widgets", systemImage: "square.grid.2x2")
                }
            }

            Section {
                Toggle("Quick actions on the app icon", isOn: $quickActionsOn)
                Button {
                    if let settings = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settings)
                    }
                } label: {
                    HStack {
                        Label("Make Zalla your default browser", systemImage: "safari")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Zalla in the Settings app")
            } header: {
                Text("Icon and default browser")
            } footer: {
                Text(DefaultBrowser.settingsFooter + " " + DefaultBrowser.quickActionsFooter)
            }
        }
    }

    @ViewBuilder
    private var premiumTab: some View {
        Group {
            Section {
                Button {
                    showThemeUpsell = true
                } label: {
                    HStack {
                        Label("Zalla Unlock", systemImage: "sparkles")
                        Spacer()
                        Text(unlock.isUnlocked ? "Unlocked" : "Locked")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Zalla Unlock")
                NavigationLink {
                    ThemePacksView()
                } label: {
                    Label("Theme packs", systemImage: "sparkles")
                }
            } header: {
                Text("Zalla Unlock")
            } footer: {
                Text("Zalla Unlock is optional. Core browsing, blocking, Privacy Shield, and Burn It All stay free.")
            }

            Section {
                PremiumPrivacyRows()
            } header: {
                Text("Private tabs and auto-clear")
            }

            Section {
                Toggle("Video Saver", isOn: $videoSaverOn)
                    .onChange(of: videoSaverOn) { _, _ in
                        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
                    }
            } header: {
                Text("Video Saver")
            } footer: {
                Text(VideoSaver.settingsFooter(unlocked: unlock.isUnlocked))
            }
        }
    }

    @ViewBuilder
    private var aboutTab: some View {
        Group {
            Section("Our promise") {
                Label("No Zalla account required", systemImage: "person.crop.circle.badge.checkmark")
                Label("No built-in analytics or advertising SDKs", systemImage: "hand.raised")
                Label("Bookmarks and history saved on this device", systemImage: "iphone")
                Text("Websites and your chosen search engine receive the requests you send them. Zalla does not provide a VPN or anonymity service.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    SupportZallaView(theme: theme)
                } label: {
                    SupportZallaRow(theme: theme)
                }
            } footer: {
                Text("Optional tips through the App Store. They do not unlock features.")
            }

            Section {
                Link(destination: URL(string: "https://zalla.gg/privacy/")!) {
                    Label("Privacy Policy", systemImage: "doc.text")
                }
                Link(destination: URL(string: "https://zalla.gg/support/")!) {
                    Label("Support", systemImage: "questionmark.circle")
                }
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Label("Acknowledgements", systemImage: "text.book.closed")
                }
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About Zalla", systemImage: "info.circle")
                }
            } header: {
                Text("Privacy and support")
            } footer: {
                Text("Privacy Policy and Support open zalla.gg in Safari.")
            }

            Section("Version") {
                Text("Zalla \(versionString)")
                Text("Core browsing, blocking of trackers and common ads, Privacy Shield, HTTPS-Only Mode, Burn It All, the privacy report, and image export are free. Zalla Unlock is an optional one time purchase for stronger blocking, Face ID for private tabs, tab groups, listening to pages, per-site CSS, scheduled auto-clear, background packs, and the Space, Jungle, Volcano, Deep Ocean, Retro Arcade, Neon City, Arctic, and Cherry Blossom theme packs.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var previewIsDark: Bool {
        switch appearance {
        case "Dark": return true
        case "Light": return false
        default: return colorScheme == .dark
        }
    }

    private var iconGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 14) {
            ForEach(AppIconPreference.allCases) { option in
                iconOption(option)
            }
        }
        .padding(.vertical, 6)
    }

    private func iconOption(_ option: AppIconPreference) -> some View {
        let isSelected = appIconPreference == option.rawValue
        return Button {
            if option.requiresUnlock && !unlock.isUnlocked {
                showThemeUpsell = true
                return
            }
            appIconPreference = option.rawValue
        } label: {
            VStack(spacing: 6) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .padding(3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(isSelected ? theme.primary : Color.clear, lineWidth: 2.5)
                    }
                    .scaleEffect(isSelected ? 1.06 : 1)
                    .motion(.pop, value: isSelected)
                Text(option.requiresUnlock && !unlock.isUnlocked ? "\(option.displayName) \u{1F512}" : option.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? theme.primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.displayName) icon")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func themeRow(title: String?, ids: [ZallaThemeID]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 12) {
                ForEach(ids) { id in
                    let swatch = ZallaTheme.theme(for: id)
                    let isChosen = !useCustomAccent && themeID == id.rawValue
                    Button {
                        selectTheme(id)
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(swatch.gradient)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if isChosen {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .scaleEffect(isChosen ? 1.1 : 1)
                                .motion(.pop, value: isChosen)
                            HStack(spacing: 2) {
                                Text(id.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                if id.requiresUnlock && !unlock.isUnlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(id.requiresUnlock && !unlock.isUnlocked ? "\(id.displayName), needs Zalla Unlock" : id.displayName)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// A swatch tap. Packs apply the whole look, plain accents set the color, locked themes open Zalla Unlock.
    /// Either way the custom accent is switched off, as before.
    private func selectTheme(_ id: ZallaThemeID) {
        switch QuickTheme.action(for: id, unlocked: unlock.isUnlocked, fullLook: quickThemeFullLook) {
        case .needsUnlock:
            showThemeUpsell = true
        case .accentOnly:
            useCustomAccent = false
            themeID = id.rawValue
            suggestIconForTheme = id
        case .fullPack(let pack):
            useCustomAccent = false
            themeID = pack.themeID.rawValue
            appIconPreference = pack.icon.rawValue
            applyIcon(pack.icon)
            newTabBackgroundRaw = NewTabBackground.preset(pack.backgroundPresetID).storageValue
            quickThemeKind = pack.transition
            quickThemePulse += 1
        }
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
                let data = try Data(contentsOf: url)
                guard let text = BookmarkHTML.text(from: data) else {
                    bookmarkMessage = "That file could not be read as text. Export bookmarks as HTML from Safari or Chrome and try again."
                    return
                }
                Task { @MainActor in
                    let pages = await BookmarkHTML.parseInBackground(text)
                    let added = browser.importBookmarks(pages)
                    bookmarkMessage = added == 0
                        ? "No new bookmarks were found in that file. Zalla reads the HTML file that Safari, Chrome, and Firefox export."
                        : "Imported \(added) bookmark\(added == 1 ? "" : "s")."
                }
            } catch {
                bookmarkMessage = error.localizedDescription
            }
        }
    }
}
