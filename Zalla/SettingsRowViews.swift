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

    /// Redesign phase 4: the glyph in the accent color on a soft accent chip, instead of white on a solid
    /// Apple style tile, so Settings matches the rest of Zalla.
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint.opacity(0.22), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Redesign phase 4: themed Settings

/// The page behind every Settings screen: the grouped background washed with the current theme.
struct SettingsBackdrop: View {
    let theme: ZallaTheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [theme.primary.opacity(0.16), theme.gradientEnd.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Hides the stock list background and puts the themed one behind it.
    func zallaSettingsBackground(_ theme: ZallaTheme) -> some View {
        scrollContentBackground(.hidden)
            .background(SettingsBackdrop(theme: theme))
    }
}

/// The card at the top of the main Settings screen.
struct SettingsHeaderCard: View {
    let theme: ZallaTheme
    let version: String
    let unlocked: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image("ZallaMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .padding(6)
                    .background(Circle().fill(.white.opacity(0.18)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Zalla")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(unlocked ? "Zalla Unlock is on" : "Free version")
                        .font(.subheadline.weight(.medium))
                        .opacity(0.9)
                }
                Spacer(minLength: 0)
                Text(version)
                    .font(.caption.monospacedDigit())
                    .opacity(0.8)
            }
            if !unlocked {
                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("See what Zalla Unlock adds")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.gradient)
                .shadow(color: theme.primary.opacity(0.3), radius: 14, y: 6)
        )
    }
}

/// One of the four quick toggle tiles on the main Settings screen.
struct QuickToggleTile: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool
    let theme: ZallaTheme

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOn.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text(isOn ? "On" : "Off")
                        .font(.caption.weight(.bold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isOn ? Color.clear : theme.primary.opacity(0.18), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to turn \(isOn ? "off" : "on").")
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

/// Build 44: rarely changed rows sit behind "More options" at the end of a section, closed by default.
struct MoreOptionsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            content()
        } label: {
            Text(SettingsRowID.moreOptionsTitle)
                .foregroundStyle(.secondary)
        }
    }
}
