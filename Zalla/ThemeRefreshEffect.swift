import SwiftUI

/// The short animation that plays when a themed pack's page refreshes: a rocket up the middle for Space,
/// a tree brushing across for Jungle. One glyph, one animation, then it is removed, so it costs almost no battery.
struct ThemeRefreshEffect: View {
    let pack: ThemePack?
    /// Changes every time the page is refreshed.
    let pulse: Int

    @State private var running = false
    @State private var visible = false

    var body: some View {
        GeometryReader { geo in
            if visible, let pack {
                switch pack.refresh {
                case .rocket:
                    Text(pack.refreshGlyph)
                        .font(.system(size: 56))
                        .position(x: geo.size.width / 2, y: running ? -60 : geo.size.height + 60)
                case .tree:
                    Text(pack.refreshGlyph)
                        .font(.system(size: 88))
                        .rotationEffect(.degrees(running ? 8 : -8))
                        .position(x: running ? geo.size.width + 90 : -90, y: geo.size.height * 0.55)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: pulse) { _, _ in play() }
    }

    private func play() {
        guard pack != nil else { return }
        running = false
        visible = true
        withAnimation(.easeIn(duration: 0.9)) { running = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            visible = false
            running = false
        }
    }
}
