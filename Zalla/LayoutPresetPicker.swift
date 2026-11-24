import SwiftUI

/// Redesign phase 2: the one Layout picker shared by setup and Settings. A live preview, four preset cards, and a
/// Top or Bottom switch for the presets that have one. It reads and writes the same three stored settings as before.
struct LayoutPresetPicker: View {
    let theme: ZallaTheme
    let isDark: Bool
    var showsPreview = true
    @AppStorage(BarLayout.storageKey) private var barLayoutRaw = BarLayout.defaultLayout.rawValue
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @AppStorage(AddressBarPlacement.storageKey) private var placementRaw = AddressBarPlacement.bottom.rawValue

    private var barLayout: BarLayout { BarLayout.stored(barLayoutRaw) }
    private var style: ToolbarStyle { ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic }
    private var placement: AddressBarPlacement { AddressBarPlacement(rawValue: placementRaw) ?? .bottom }
    private var current: LayoutPreset { LayoutPreset.current(layout: barLayout, style: style, placement: placement) }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsPreview {
                ChromeStylePreview(style: style, placement: placement, isDark: isDark, theme: theme, barLayout: barLayout)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(LayoutPreset.allCases) { preset in
                    presetCard(preset)
                }
            }
            if current.supportsTopPlacement {
                Picker("Address bar", selection: placementBinding) {
                    Text("Bottom").tag(AddressBarPlacement.bottom.rawValue)
                    Text("Top").tag(AddressBarPlacement.top.rawValue)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Address bar position")
            } else {
                Text("Safari Style always sits at the bottom. Pick another layout to put the address bar on top.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func presetCard(_ preset: LayoutPreset) -> some View {
        let selected = preset == current
        return Button {
            pick(preset)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: preset.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selected ? .white : theme.primary)
                        .frame(width: 34, height: 34)
                        .background(
                            selected ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(theme.primary.opacity(0.12)),
                            in: Circle()
                        )
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(selected ? theme.primary : Color.secondary.opacity(0.5))
                }
                Text(preset.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(preset.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? theme.primary.opacity(0.08) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? theme.primary.opacity(0.45) : Color.primary.opacity(0.10), lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(preset.title)
        .accessibilityHint(preset.summary)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func pick(_ preset: LayoutPreset) {
        let next = preset.settings(placement: placement)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            barLayoutRaw = next.layout.rawValue
            toolbarStyleRaw = next.style.rawValue
            placementRaw = next.placement.rawValue
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private var placementBinding: Binding<String> {
        Binding(
            get: { placementRaw },
            set: { newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    placementRaw = newValue
                }
            }
        )
    }
}
