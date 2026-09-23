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
                    .padding(.vertical, 12)
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

    static func highlightedID(at point: CGPoint, items: [HoldRevealItem], in bounds: CGRect) -> Int? {
        guard !items.isEmpty else { return nil }
        let rowHeight: CGFloat = 56
        let sheetHeight = CGFloat(items.count) * rowHeight
        let bottomPadding: CGFloat = 110
        let sheetTop = bounds.height - bottomPadding - sheetHeight
        let sheetBottom = bounds.height - bottomPadding
        guard point.y >= sheetTop - 48, point.y <= sheetBottom + 24 else { return nil }
        let index = min(max(Int((point.y - sheetTop) / rowHeight), 0), items.count - 1)
        return items[index].id
    }
}
