import SwiftUI

struct HoldRevealItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let subtitle: String
}

enum HoldRevealKind: Equatable {
    case back
    case forward
}

struct HoldRevealMenu: View {
    let items: [HoldRevealItem]
    let highlightedID: Int?
    var onTapItem: ((HoldRevealItem) -> Void)? = nil

    static let rowHeight: CGFloat = 64
    static let bottomPadding: CGFloat = 118

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let highlighted = highlightedID == item.id
                Button {
                    onTapItem?(item)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(item.id)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(highlighted ? .white : .secondary)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle().fill(highlighted ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(highlighted ? .white : .primary)
                                .lineLimit(1)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(highlighted ? .white.opacity(0.85) : .secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(minHeight: Self.rowHeight)
                    .background(highlighted ? Color.accentColor : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < items.count - 1 {
                    Divider().padding(.leading, 50)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }

    /// Hit-test using the menu's own global frame when available; falls back to screen geometry.
    static func highlightedID(
        at point: CGPoint,
        items: [HoldRevealItem],
        in bounds: CGRect,
        menuFrame: CGRect? = nil
    ) -> Int? {
        guard !items.isEmpty else { return nil }
        let rowHeight = Self.rowHeight
        let sheetHeight = CGFloat(items.count) * rowHeight

        let sheetTop: CGFloat
        let sheetBottom: CGFloat
        let sheetLeading: CGFloat
        let sheetTrailing: CGFloat

        if let menuFrame, menuFrame.width > 8, menuFrame.height > 8 {
            sheetTop = menuFrame.minY
            sheetBottom = menuFrame.maxY
            sheetLeading = menuFrame.minX - 36
            sheetTrailing = menuFrame.maxX + 36
        } else {
            sheetTop = bounds.height - Self.bottomPadding - sheetHeight
            sheetBottom = bounds.height - Self.bottomPadding
            sheetLeading = bounds.minX + 12
            sheetTrailing = bounds.maxX - 12
        }

        // Extra-forgiving hit targets so finger drag stays on the intended control.
        guard point.y >= sheetTop - 72, point.y <= sheetBottom + 56 else { return nil }
        guard point.x >= sheetLeading - 12, point.x <= sheetTrailing + 12 else { return nil }

        let relativeY = min(max(point.y - sheetTop, 0), sheetHeight - 1)
        let index = min(max(Int(relativeY / rowHeight), 0), items.count - 1)
        return items[index].id
    }
}
