import SwiftUI

/// One control revealed by the Quick Action button.
struct QuickActionEntry: Identifiable {
    let item: ToolbarItemKind
    var enabled: Bool = true
    var badge: String?
    /// State-dependent overrides, such as Reload becoming Stop while a page loads.
    var titleOverride: String?
    var symbolOverride: String?
    let action: () -> Void
    /// Optional press-and-hold action, used by Back and Forward to peek history.
    var onHold: (() -> Void)?

    var id: String { item.id }
    var title: String { titleOverride ?? item.title }
    var symbolName: String { symbolOverride ?? item.symbolName }
}

/// Measures the Quick Action button so the fan can open from its exact center.
struct QuickActionFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// The Quick Action fan: controls spring out in an arc from the crimson button.
/// Opens upward for bottom chrome and downward for top chrome.
struct QuickActionFan: View {
    let anchor: CGRect
    let placement: AddressBarPlacement
    let theme: ZallaTheme
    let entries: [QuickActionEntry]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spread = false
    @State private var heldEntryID: String?

    private static let buttonSize = CGFloat(QuickActionLayout.buttonSize)

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let center = fanCenter(in: frame)
            ZStack {
                Color.black
                    .opacity(spread ? 0.32 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismiss)
                    .accessibilityHidden(true)

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let offset = QuickActionLayout.offset(index: index, count: entries.count, placement: placement)
                    fanButton(entry)
                        .scaleEffect(spread ? 1 : 0.35)
                        .opacity(spread ? 1 : 0)
                        .position(
                            x: center.x + (spread ? offset.width : 0),
                            y: center.y + (spread ? offset.height : 0)
                        )
                        .animation(
                            Motion.animation(.pop, reduceMotion: reduceMotion)?.delay(Double(index) * 0.02),
                            value: spread
                        )
                }

                closeButton
                    .position(center)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withMotion(.fade, reduceMotion: reduceMotion) { spread = true }
        }
    }

    private func fanCenter(in frame: CGRect) -> CGPoint {
        guard anchor != .zero else {
            let y = placement == .bottom ? frame.height - 80 : 80
            return CGPoint(x: frame.width / 2, y: y)
        }
        return CGPoint(x: anchor.midX - frame.minX, y: anchor.midY - frame.minY)
    }

    private func dismiss() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withMotion(.fade, reduceMotion: reduceMotion) { spread = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onDismiss()
        }
    }

    private func fanButton(_ entry: QuickActionEntry) -> some View {
        Button {
            guard entry.enabled else { return }
            // A completed press-and-hold already handled this touch.
            if heldEntryID == entry.id {
                heldEntryID = nil
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onDismiss()
            entry.action()
        } label: {
            ZStack(alignment: .topTrailing) {
                // The icon and its label both sit inside the circle.
                VStack(spacing: 3) {
                    Image(systemName: entry.symbolName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(entry.enabled ? theme.primary : Color.secondary)
                    Text(entry.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 4)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(theme.primary.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                if let badge = entry.badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(theme.primary, in: Capsule())
                        .offset(x: 2, y: -2)
                }
            }
            .opacity(entry.enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!entry.enabled)
        .simultaneousGesture(holdGesture(for: entry), including: entry.onHold == nil ? .none : .all)
        .accessibilityLabel(accessibilityLabel(for: entry))
        .accessibilityActions {
            if entry.enabled, let onHold = entry.onHold {
                Button("Show history") {
                    onDismiss()
                    onHold()
                }
            }
        }
    }

    private func holdGesture(for entry: QuickActionEntry) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .onEnded { _ in
                guard entry.enabled, let onHold = entry.onHold else { return }
                heldEntryID = entry.id
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDismiss()
                onHold()
            }
    }

    private func accessibilityLabel(for entry: QuickActionEntry) -> String {
        if entry.item == .tabs, let badge = entry.badge {
            return "Tabs, \(badge) open"
        }
        return entry.title
    }

    private var closeButton: some View {
        Button(action: dismiss) {
            QuickActionGlyph(theme: theme, isOpen: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close quick actions")
    }
}

/// The crimson center control. Shared by the chrome and the open fan so they line up exactly.
struct QuickActionGlyph: View {
    let theme: ZallaTheme
    var isOpen: Bool = false
    static let size: CGFloat = 54
    /// The drawn diameter. The fan uses the default; the floating bar passes a slightly smaller one.
    var diameter: CGFloat = QuickActionGlyph.size

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.gradient)
            Circle()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            Image(systemName: isOpen ? "xmark" : "circle.grid.2x2.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: theme.primary.opacity(0.42), radius: 12, y: 5)
        .contentShape(Circle())
    }
}
