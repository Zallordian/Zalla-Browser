import SwiftUI
import UIKit
import WebKit

/// A flame with the Zalla mark inside it. Drawn from a system flame and the bundled Zalla mark,
/// so it follows Dynamic Type sizing through the size you give it. The flame takes the current accent color.
struct FlameMark: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tint)
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
    /// Asks first, then wipes everything and returns to one fresh tab. It never quits the app.
    /// An alert, not a confirmation dialog: on iPhone a dialog can show up as a popover pinned to whatever
    /// view it hangs off, which put it at the top of the Menu sheet. An alert is always centered.
    func flameConfirmation(isPresented: Binding<Bool>, browser: BrowserStore, onBurn: @escaping () -> Void = {}) -> some View {
        alert("Burn It All?", isPresented: isPresented) {
            Button("Burn It All", role: .destructive) {
                onBurn()
                Task { await browser.burnEverything() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(BurnCopy.confirmationMessage)
        }
    }
}
