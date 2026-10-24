import SwiftUI

/// Build 41: one Settings row label, Brave style. A colored icon tile, the title, an optional subtitle, and an
/// optional value or lock on the right. Chevrons come from NavigationLink itself.
struct SettingsRowLabel: View {
    let row: SettingsRowID
    var subtitle: String?
    var value: String?
    var tint: Color = .accentColor
    var locked = false

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconTile(symbol: row.symbol, tint: row.kind == .destructive ? .red : tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .foregroundStyle(row.kind == .destructive ? Color.red : Color.primary)
                if let line = subtitle ?? row.subtitle {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if locked {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Needs Zalla Unlock")
            } else if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingsIconTile: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint))
            .accessibilityHidden(true)
    }
}

/// The round accent checkmark in the top right of Settings.
struct SettingsDoneButton: View {
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
    }
}

/// Address bar at the top or the bottom, picked from two small pictures of the toolbar.
struct AddressBarPicker: View {
    @Binding var selection: String
    let style: ToolbarStyle
    let isDark: Bool
    let theme: ZallaTheme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AddressBarPlacement.allCases) { placement in
                AddressBarOption(
                    placement: placement,
                    style: style,
                    isDark: isDark,
                    theme: theme,
                    selected: selection == placement.rawValue
                ) { selection = placement.rawValue }
            }
        }
        .padding(.vertical, 6)
    }
}

struct AddressBarOption: View {
    let placement: AddressBarPlacement
    let style: ToolbarStyle
    let isDark: Bool
    let theme: ZallaTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ChromeStylePreview(style: style, placement: placement, isDark: isDark, theme: theme)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? theme.primary : Color.primary.opacity(0.12), lineWidth: selected ? 2.5 : 0.5)
                    )
                    .allowsHitTesting(false)
                Label(placement == .top ? "Top Bar" : "Bottom Bar", systemImage: selected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? theme.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(placement == .top ? "Address bar at the top" : "Address bar at the bottom")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Settings, Display, Page Zoom: the sites with a saved zoom level, with swipe to forget and Reset all.
struct PageZoomListView: View {
    @State private var store: [String: Double] = PageZoom.load()

    private var hosts: [String] { store.keys.sorted() }

    var body: some View {
        List {
            Section {
                if hosts.isEmpty {
                    Text("No sites have a saved zoom yet. Use Page Zoom in the Menu on any site.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hosts, id: \.self) { host in
                        HStack {
                            Text(host)
                            Spacer()
                            Text(PageZoom.percentText(PageZoom.level(for: host, in: store)))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .onDelete(perform: forget)
                }
            } footer: {
                Text("Each site keeps its own zoom. Swipe to forget one.")
            }
            if !hosts.isEmpty {
                Section {
                    Button("Reset All Sites", role: .destructive) {
                        store = [:]
                        PageZoom.save([:])
                    }
                }
            }
        }
        .navigationTitle("Page Zoom")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func forget(_ offsets: IndexSet) {
        let list = hosts
        for index in offsets where list.indices.contains(index) {
            store[list[index]] = nil
        }
        PageZoom.save(store)
    }
}
