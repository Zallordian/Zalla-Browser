import SwiftUI

/// The strip of category tabs across the top of Settings. It scrolls sideways when the text is large, shows the
/// selected tab in the accent color with an underline, and keeps the selected tab in view.
struct SettingsTabStrip: View {
    @Binding var selection: SettingsCategory
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(SettingsCategory.allCases) { category in
                        tab(category)
                            .id(category)
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: selection) { _, newValue in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings categories")
    }

    private func tab(_ category: SettingsCategory) -> some View {
        let selected = selection == category
        return Button {
            selection = category
        } label: {
            VStack(spacing: 4) {
                Image(systemName: category.symbolName)
                    .font(.title3)
                    .imageScale(.medium)
                Text(category.title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Capsule()
                    .fill(selected ? accent : Color.clear)
                    .frame(height: 3)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: selected)
            }
            .foregroundStyle(selected ? accent : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .frame(minWidth: 72, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.title)
        .accessibilityHint("Shows \(category.title) settings")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
