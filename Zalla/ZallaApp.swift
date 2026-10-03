import SwiftUI
import UIKit

@main
struct ZallaApp: App {
    @UIApplicationDelegateAdaptor(ZallaAppDelegate.self) private var appDelegate
    @StateObject private var browser = BrowserStore()
    /// Icon quick actions land here first, then move to the browser once it is on screen.
    @ObservedObject private var quickActions = QuickActionRouter.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"
    @AppStorage("customAccentGradient") private var customAccentGradient = true
    @AppStorage("appIconPreference") private var appIconPreference = AppIconPreference.default.rawValue
    /// Watched so a lapsed Unlock re-resolves the accent right away instead of at the next launch.
    @StateObject private var unlock = ZallaUnlock.shared

    private var theme: ZallaTheme {
        ZallaTheme.resolved(
            themeID: themeID,
            useCustom: useCustomAccent,
            customHex: customAccentHex,
            gradient: customAccentGradient
        )
    }

    /// Without Zalla Unlock, a locked app icon goes back to the primary icon. The accent already falls back on its own.
    private func fallBackIfLocked() {
        guard !unlock.isUnlocked else { return }
        let storedIsLocked = AppIconPreference(rawValue: appIconPreference)?.requiresUnlock ?? false
        let activeIsLocked = AppIconPreference.allCases.contains {
            $0.requiresUnlock && $0.alternateIconName == UIApplication.shared.alternateIconName
        }
        guard storedIsLocked || activeIsLocked else { return }
        appIconPreference = AppIconPreference.default.rawValue
        AppIconPreference.apply(.default)
    }

    @MainActor
    private func handOverQuickAction(_ action: QuickAction?) {
        guard let action else { return }
        quickActions.pending = nil
        browser.pendingQuickAction = action
    }

    @MainActor
    private func syncWidgets() {
        WidgetSync.refresh(bookmarks: browser.bookmarks)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    BrowserView(browser: browser)
                } else {
                    OnboardingView(browser: browser)
                }
            }
            .tint(theme.primary)
            // Swipe down on any scrolling screen to put the keyboard away.
            .scrollDismissesKeyboard(.interactively)
            .onOpenURL { url in
                // A zalla:// action link (widgets) asks for something. Anything else is a web address.
                if let action = QuickAction.resolve(url: url) {
                    browser.pendingQuickAction = action
                } else {
                    browser.openIncoming(url)
                }
            }
            .onChange(of: quickActions.pending) { _, action in
                handOverQuickAction(action)
            }
            .overlay {
                if scenePhase != .active {
                    ZStack {
                        Color(uiColor: .systemBackground).ignoresSafeArea()
                        Label("Zalla", systemImage: "shield.lefthalf.filled")
                            .font(.largeTitle.bold())
                            .foregroundStyle(theme.primary)
                    }
                }
            }
            .task {
                // A quick action that launched Zalla is already waiting.
                handOverQuickAction(quickActions.pending)
                syncWidgets()
                // Finish any tip purchases that completed while Zalla was closed or awaiting approval.
                TipTransactionObserver.start()
                // Confirm Zalla Unlock with StoreKit; the cached answer is used until then.
                await ZallaUnlock.shared.refreshEntitlements()
                fallBackIfLocked()
                await browser.runAutoClearIfDue()
            }
            .onChange(of: unlock.isUnlocked) { _, _ in
                fallBackIfLocked()
            }
            .onChange(of: scenePhase) { _, phase in
                // Save open tabs whenever Zalla leaves the foreground so a cold launch can restore them.
                if phase != .active {
                    browser.saveSession()
                    // Widgets pick up the latest accent, favorites, and Privacy Report totals.
                    syncWidgets()
                }
                // Only .background, not .inactive: the Face ID sheet itself makes the app inactive.
                if phase == .background {
                    browser.lockPrivateTabsIfNeeded()
                }
                if phase == .active {
                    Task { await browser.runAutoClearIfDue() }
                }
            }
        }
    }
}
