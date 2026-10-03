import SwiftUI

/// Remembers which hosts' app banners were dismissed. Memory only: nothing is saved, and it is gone when Zalla closes.
/// Private tabs have their own list so they never touch normal browsing.
/// Used from the main thread only.
final class AppBannerSession: ObservableObject {
    static let shared = AppBannerSession()

    @Published private(set) var normal = AppBannerDismissals()
    @Published private(set) var privateTabs = AppBannerDismissals()

    /// Forgets every dismissal (Burn It All).
    func reset() {
        normal.reset()
        privateTabs.reset()
    }

    func isDismissed(_ hostKey: String, isPrivate: Bool) -> Bool {
        isPrivate ? privateTabs.isDismissed(hostKey) : normal.isDismissed(hostKey)
    }

    func dismiss(_ hostKey: String, isPrivate: Bool) {
        if isPrivate {
            privateTabs.dismiss(hostKey)
        } else {
            normal.dismiss(hostKey)
        }
    }
}

/// The slim "Open in the app" banner under the status bar. It reads like Safari's: a dismiss button, the name, and an
/// Open button. Zalla only tries to open the app through a universal link; it never goes to the App Store.
struct AppBannerView: View {
    let info: AppBannerInfo
    let accent: Color
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss app banner")
            Image(systemName: "arrow.up.forward.app.fill")
                .font(.title3)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.appName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("Open in the \(info.appName) app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: onOpen) {
                Text("Open")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(accent, in: Capsule(style: .continuous))
            }
            .accessibilityLabel("Open in the \(info.appName) app")
            .accessibilityHint("Opens the app if it is installed")
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 0.75)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}
