import SwiftUI
import UIKit
import WebKit

/// A flame with the Zalla mark inside it. Drawn from a system flame and the bundled Zalla mark,
/// so it follows Dynamic Type sizing through the size you give it.
struct FlameMark: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.78, blue: 0.25), Color(red: 0.98, green: 0.36, blue: 0.16), Color(red: 0.86, green: 0.15, blue: 0.20)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Image("ZallaMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(y: size * 0.14)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Asks first, then wipes everything and closes the app.
    func flameConfirmation(isPresented: Binding<Bool>, browser: BrowserStore, onBurn: @escaping () -> Void = {}) -> some View {
        confirmationDialog("Burn everything?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Burn it all", role: .destructive) {
                onBurn()
                Task { await browser.burnEverythingAndClose() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This closes every tab and erases history, cookies, and site data. Then Zalla closes. Bookmarks and downloads stay put.")
        }
    }
}

/// Shown while the flame works, so nobody wonders whether the tap registered.
struct FlameProgressOverlay: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).opacity(0.94).ignoresSafeArea()
            VStack(spacing: 14) {
                FlameMark(size: 64)
                Text("Clearing everything")
                    .font(.headline)
                Text("Zalla will close in a moment. Open it again for a clean slate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .accessibilityElement(children: .combine)
    }
}
