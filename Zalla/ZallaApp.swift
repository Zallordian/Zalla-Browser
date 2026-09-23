import SwiftUI

@main
struct ZallaApp: App {
    @StateObject private var browser = BrowserStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue

    private var theme: ZallaTheme { ZallaTheme.theme(forRaw: themeID) }

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
        }
    }
}
