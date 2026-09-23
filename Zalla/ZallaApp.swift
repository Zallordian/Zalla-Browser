import SwiftUI

@main
struct ZallaApp: App {
    @StateObject private var browser = BrowserStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            BrowserView(browser: browser)
                .tint(Color(red: 0.89, green: 0.23, blue: 0.31))
                .overlay {
                    if scenePhase != .active {
                        ZStack {
                            Color(uiColor: .systemBackground).ignoresSafeArea()
                            Label("Zalla", systemImage: "shield.lefthalf.filled")
                                .font(.largeTitle.bold())
                        }
                    }
                }
        }
    }
}
