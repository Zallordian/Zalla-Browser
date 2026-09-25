import SwiftUI

@main
struct ZallaApp: App {
    @StateObject private var browser = BrowserStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"
    @AppStorage("customAccentGradient") private var customAccentGradient = true

    private var theme: ZallaTheme {
        ZallaTheme.resolved(
            themeID: themeID,
            useCustom: useCustomAccent,
            customHex: customAccentHex,
            gradient: customAccentGradient
        )
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
            .onChange(of: scenePhase) { _, phase in
                // Save open tabs whenever Zalla leaves the foreground so a cold launch can restore them.
                if phase != .active {
                    browser.saveSession()
                }
            }
        }
    }
}
