import SwiftUI

/// Customize Toolbar: reorder, add, and remove buttons for each toolbar style.
/// The address pill and Menu stay put so every action remains reachable.
struct ToolbarEditorView: View {
    let theme: ZallaTheme
    @AppStorage(ToolbarLayout.storageKey) private var layoutData = Data()
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @AppStorage(AddressBarPlacement.storageKey) private var addressBarPlacementRaw = AddressBarPlacement.bottom.rawValue
    @AppStorage("appearance") private var appearance = "System"
    @Environment(\.colorScheme) private var colorScheme
    @State private var target: ToolbarEditTarget = .classic
    @State private var layout = ToolbarLayout.default
    @State private var didLoad = false

    private var currentItems: [ToolbarItemKind] { layout.items(for: target) }

    private var previewIsDark: Bool {
        switch appearance {
        case "Dark": return true
        case "Light": return false
        default: return colorScheme == .dark
        }
    }

    var body: some View {
        List {
            previewSection
            itemsSection
            availableSection
            Section {
                Button("Reset to Default", role: .destructive) {
                    update { $0.reset(target) }
                }
                .disabled(layout.items(for: target) == ToolbarLayout.default.items(for: target))
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Customize Toolbar")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
        .onAppear(perform: load)
    }

    private var previewSection: some View {
        Section {
            Picker("Style", selection: $target) {
                ForEach(ToolbarEditTarget.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            ChromeStylePreview(
                style: target.style,
                placement: AddressBarPlacement(rawValue: addressBarPlacementRaw) ?? .bottom,
                isDark: previewIsDark,
                theme: theme,
                toolbarItems: layout
            )
            .padding(.vertical, 6)
            if target == .quickActionFan {
                FanPreviewRow(items: layout.quickActionFan, theme: theme)
            }
        } footer: {
            Text("Changes apply right away. Items you remove stay available in the Menu.")
        }
    }

    private var itemsSection: some View {
        Section {
            ForEach(currentItems) { kind in
                ToolbarEditorRow(kind: kind, isPinned: !layout.canRemove(kind, from: target), theme: theme)
                    .deleteDisabled(!layout.canRemove(kind, from: target))
            }
            .onMove { offsets, destination in
                update { $0.move(fromOffsets: offsets, toOffset: destination, in: target) }
            }
            .onDelete { offsets in
                update { $0.remove(atOffsets: offsets, from: target) }
            }
        } header: {
            Text("In Toolbar")
        } footer: {
            Text(limitText)
        }
    }

    private var availableSection: some View {
        Section {
            ForEach(layout.available(for: target)) { kind in
                Button {
                    update { $0.add(kind, to: target) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(layout.canAdd(to: target) ? Color.green : Color.secondary)
                        Label(kind.title, systemImage: kind.symbolName)
                            .foregroundStyle(layout.canAdd(to: target) ? Color.primary : Color.secondary)
                    }
                }
                .disabled(!layout.canAdd(to: target))
                .deleteDisabled(true)
                .moveDisabled(true)
            }
        } header: {
            Text("Available")
        } footer: {
            if !layout.canAdd(to: target) {
                Text("\(target.title) is full. Remove an item to add another.")
            }
        }
    }

    private var limitText: String {
        let count = layout.buttonCount(for: target)
        var text = "\(count) of \(target.limit) buttons."
        if target.usesAddressPill {
            text += " Drag buttons above or below the Address Bar to place them on either side of it."
        }
        if target.requiresMenu {
            text += " Menu always stays so every action is reachable."
        }
        return text
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        layout = ToolbarLayout.decode(layoutData)
        target = ToolbarEditTarget.forStyle(ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic)
    }

    private func update(_ change: (inout ToolbarLayout) -> Void) {
        var copy = layout
        change(&copy)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            layout = copy
        }
        layoutData = copy == .default ? Data() : copy.encoded()
    }
}

private struct ToolbarEditorRow: View {
    let kind: ToolbarItemKind
    let isPinned: Bool
    let theme: ZallaTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 28)
            Text(kind.title)
            Spacer(minLength: 8)
            if isPinned {
                Text("Required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Small row of the Quick Action fan buttons, in order.
private struct FanPreviewRow: View {
    let items: [ToolbarItemKind]
    let theme: ZallaTheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { kind in
                Image(systemName: kind.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 30, height: 30)
                    .background(theme.primary.opacity(0.1), in: Circle())
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fan: \(items.map(\.title).joined(separator: ", "))")
    }
}
