import SwiftUI
import UIKit

/// Holds an action that arrived from the app icon menu until the browser can take it. On a cold launch the action
/// shows up before any screen exists, so it waits here and ZallaApp hands it over.
@MainActor
final class QuickActionRouter: ObservableObject {
    static let shared = QuickActionRouter()

    @Published var pending: QuickAction?

    private init() {}

    /// Returns true when the shortcut was one of Zalla's and the setting allows it.
    @discardableResult
    func handle(shortcutType: String) -> Bool {
        guard let action = QuickAction.resolve(shortcutType: shortcutType, enabled: QuickAction.isEnabled()) else {
            return false
        }
        pending = action
        return true
    }
}

/// The SwiftUI life cycle has no hook for icon quick actions, so a small app delegate supplies a scene delegate.
/// A shortcut that launches Zalla arrives with the scene connection options. One chosen while Zalla is running
/// or suspended arrives at the scene delegate.
@MainActor
final class ZallaAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let item = options.shortcutItem {
            QuickActionRouter.shared.handle(shortcutType: item.type)
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = ZallaSceneDelegate.self
        return configuration
    }
}

@MainActor
final class ZallaSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickActionRouter.shared.handle(shortcutType: shortcutItem.type))
    }
}
