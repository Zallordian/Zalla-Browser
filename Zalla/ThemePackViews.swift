import SwiftUI

/// Settings screen for the Space and Jungle theme packs.
struct ThemePacksView: View {
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("appIconPreference") private var appIconPreference = AppIconPreference.default.rawValue
    @AppStorage(NewTabBackground.storageKey) private var backgroundRaw = NewTabBackground.standard.storageValue
    @AppStorage(ThemePacks.transitionsKey) private var transitionsOn = true
    @AppStorage(ThemeTransitionSpeed.storageKey) private var transitionSpeedRaw = ThemeTransitionSpeed.normal.rawValue
    @ObservedObject private var unlock = ZallaUnlock.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showUpsell = false
    @State private var message: String?
    @State private var previewKind: ThemeTransitionKind = .jungle
    @State private var previewPulse = 0

    private var previewPlan: ThemeTransitionPlan? {
        ThemeTransitionPlan.make(
            kind: previewKind, unlocked: unlock.isUnlocked, enabled: transitionsOn,
            reduceMotion: reduceMotion, speed: ThemeTransitionSpeed(stored: transitionSpeedRaw)
        )
    }

    var body: some View {
        List {
            ForEach(ThemePacks.all) { pack in
                Section {
                    packCard(pack)
                } footer: {
                    if !unlock.isUnlocked {
                        Text("Theme packs are part of Zalla Unlock.")
                    }
                }
            }
            Section {
                Toggle("Theme transitions", isOn: $transitionsOn)
                if transitionsOn {
                    Picker("Speed", selection: $transitionSpeedRaw) {
                        ForEach(ThemeTransitionSpeed.allCases) { speed in
                            Text(speed.rawValue).tag(speed.rawValue)
                        }
                    }
                }
            } header: {
                Text("Customization")
            } footer: {
                Text(reduceMotion
                     ? "Reduce Motion is on, so transitions are a quick fade."
                     : "A leafy curtain for Jungle, a rocket for Space. They play for about a second when you refresh and when you apply a theme.")
            }
            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Theme packs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUpsell) { ZallaUnlockSheet() }
        .overlay {
            ThemeTransitionOverlay(plan: previewPlan, pulse: previewPulse)
        }
    }

    private func packCard(_ pack: ThemePack) -> some View {
        let theme = ZallaTheme.theme(for: pack.themeID)
        let active = !useCustomAccent && themeID == pack.themeID.rawValue
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(pack.icon.previewImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(pack.name).font(.headline)
                        if !unlock.isUnlocked {
                            Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                                .accessibilityLabel("Locked")
                        }
                    }
                    Text(pack.tagline).font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let preset = NewTabCatalog.preset(id: pack.backgroundPresetID) {
                NewTabPresetFill(preset: preset)
                    .overlay { NewTabDecorView(decor: preset.decor) }
                    .frame(height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
            }
            Button {
                apply(pack)
            } label: {
                Text(active ? "Applied" : (unlock.isUnlocked ? "Apply \(pack.name)" : "Unlock \(pack.name)"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
            .disabled(active)
        }
        .padding(.vertical, 4)
    }

    /// Sets the accent, the app icon, and the new tab background together.
    private func apply(_ pack: ThemePack) {
        guard unlock.isUnlocked else {
            showUpsell = true
            return
        }
        previewKind = pack.transition
        previewPulse += 1
        useCustomAccent = false
        themeID = pack.themeID.rawValue
        appIconPreference = pack.icon.rawValue
        backgroundRaw = NewTabBackground.preset(pack.backgroundPresetID).storageValue
        AppIconPreference.apply(pack.icon) { error in
            message = error ?? "\(pack.name) is on: accent, icon, and new tab background."
        }
    }
}
