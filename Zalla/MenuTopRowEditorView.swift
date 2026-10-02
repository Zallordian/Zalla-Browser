import SwiftUI

/// Customize Menu Row: choose, reorder, and reset the actions in the top row of the Menu sheet.
/// Every action also lives further down the Menu, and Settings stays in its own Menu section.
struct MenuTopRowEditorView: View {
    let theme: ZallaTheme
    @AppStorage(MenuTopRow.storageKey) private var rowData = Data()
    @State private var row = MenuTopRow.default
    @State private var didLoad = false

    var body: some View {
        List {
            previewSection
            itemsSection
            availableSection
            Section {
                Button("Reset to Default", role: .destructive) {
                    update { $0.reset() }
                }
                .disabled(row.isDefault)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Customize Menu Row")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
        .onAppear(perform: load)
    }

    private var previewSection: some View {
        Section {
            HStack(spacing: 2) {
                ForEach(row.items) { item in
                    VStack(spacing: 4) {
                        Image(systemName: item.symbolName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(theme.primary)
                        Text(item.shortTitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Menu row: \(row.items.map(\.title).joined(separator: ", "))")
        } header: {
            Text("Preview")
        } footer: {
            Text("This is the row of buttons at the top of the Menu. Changes apply right away. Everything you remove here stays in the Menu below it.")
        }
    }

    private var itemsSection: some View {
        Section {
            ForEach(row.items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.symbolName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.primary)
                        .frame(width: 28)
                    Text(item.title)
                    Spacer(minLength: 8)
                    if !row.canRemove(item) {
                        Text("Last one")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .deleteDisabled(!row.canRemove(item))
            }
            .onMove { offsets, destination in
                update { $0.move(fromOffsets: offsets, toOffset: destination) }
            }
            .onDelete { offsets in
                update { $0.remove(atOffsets: offsets) }
            }
        } header: {
            Text("In the Menu row")
        } footer: {
            Text("\(row.items.count) of \(MenuTopRow.maxItems) buttons. Drag to reorder.")
        }
    }

    private var availableSection: some View {
        Section {
            ForEach(row.available) { item in
                Button {
                    update { $0.add(item) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(row.canAdd ? Color.green : Color.secondary)
                        Label(item.title, systemImage: item.symbolName)
                            .foregroundStyle(row.canAdd ? Color.primary : Color.secondary)
                    }
                }
                .disabled(!row.canAdd)
                .deleteDisabled(true)
                .moveDisabled(true)
            }
        } header: {
            Text("Available")
        } footer: {
            if !row.canAdd {
                Text("The row is full. Remove a button to add another.")
            }
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        row = MenuTopRow.decode(rowData)
    }

    private func update(_ change: (inout MenuTopRow) -> Void) {
        var copy = row
        change(&copy)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            row = copy
        }
        rowData = copy.isDefault ? Data() : copy.encoded()
    }
}
