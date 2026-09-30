import SwiftUI

private struct SlotWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Narrows a view to a fraction of the space its row gives it, keeping the row itself unchanged.
private struct FractionalWidthModifier: ViewModifier {
    let fraction: CGFloat
    /// 0 keeps the view on the leading edge, 0.5 centers it.
    let alignment: Alignment
    @State private var slotWidth: CGFloat = 0

    func body(content: Content) -> some View {
        Group {
            if slotWidth > 0 {
                content.frame(width: slotWidth * fraction)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SlotWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(SlotWidthKey.self) { slotWidth = $0 }
    }
}

extension View {
    /// Narrows a search bar inside its row. Full width (the default) leaves the view untouched.
    @ViewBuilder
    func searchBarWidth(_ fraction: Double, alignment: Alignment = .center) -> some View {
        if SearchBarWidth.isFull(fraction) {
            self
        } else {
            modifier(FractionalWidthModifier(fraction: CGFloat(SearchBarWidth.clamped(fraction)), alignment: alignment))
        }
    }
}
