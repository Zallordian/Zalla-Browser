import PhotosUI
import SwiftUI
import UIKit

/// The user's own new tab photo. It is resized and stored on this device only.
enum NewTabPhotoStore {
    static let revisionKey = "newTabPhotoRevision"
    private static let maxDimension: CGFloat = 1600
    private static var cached: UIImage?

    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zalla", isDirectory: true)
            .appendingPathComponent("newtab-background.jpg")
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// The saved photo, or nil when none was chosen.
    static func image() -> UIImage? {
        if let cached { return cached }
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else { return nil }
        cached = image
        return image
    }

    /// Downsizes and saves picked photo data. Returns false when the data is not an image.
    @discardableResult
    static func save(_ data: Data) -> Bool {
        guard let original = UIImage(data: data) else { return false }
        let target = CGSize(width: maxDimension, height: maxDimension)
        let scaled = original.preparingThumbnail(of: target) ?? original
        guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else { return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try jpeg.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            return false
        }
        cached = scaled
        return true
    }

    static func remove() {
        try? FileManager.default.removeItem(at: fileURL)
        cached = nil
    }
}

/// Draws the new tab background for a resolved choice.
struct NewTabBackgroundView: View {
    let background: NewTabBackground
    let theme: ZallaTheme
    let washIntensity: Double
    let photo: UIImage?

    var body: some View {
        Group {
            switch background {
            case .standard:
                standardBackground
            case .preset(let id):
                if let preset = NewTabCatalog.preset(id: id) {
                    NewTabPresetFill(preset: preset)
                } else {
                    standardBackground
                }
            case .photo:
                photoBackground
            }
        }
        .ignoresSafeArea()
    }

    private var standardBackground: some View {
        Color(uiColor: .systemGroupedBackground)
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [theme.primary.opacity(washIntensity), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 420
                )
            }
    }

    @ViewBuilder
    private var photoBackground: some View {
        if let photo {
            GeometryReader { geo in
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.3))
            }
        } else {
            standardBackground
        }
    }
}

/// A generated gradient for a preset.
struct NewTabPresetFill: View {
    let preset: NewTabPreset

    var body: some View {
        let colors = preset.colors.map { ZallaTheme.hex($0) }
        switch preset.style {
        case .linear:
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .radial:
            RadialGradient(colors: colors, center: .top, startRadius: 20, endRadius: 640)
        }
    }
}

/// Background picker opened from the pencil on the new tab page.
struct NewTabBackgroundSheet: View {
    @AppStorage(NewTabBackground.storageKey) private var storedValue = NewTabBackground.standard.storageValue
    @AppStorage(NewTabPhotoStore.revisionKey) private var photoRevision = 0
    @ObservedObject private var unlock = ZallaUnlock.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var showUpsell = false
    @State private var photoMessage: String?

    private var current: NewTabBackground { NewTabBackground(storageValue: storedValue) }
    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 12)]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LazyVGrid(columns: columns, spacing: 14) {
                        standardTile
                        ForEach(NewTabCatalog.free) { preset in
                            presetTile(preset)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Included")
                }

                ForEach(NewTabCatalog.packs) { pack in
                    Section {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(NewTabCatalog.presets(inPack: pack.id)) { preset in
                                presetTile(preset)
                            }
                        }
                        .padding(.vertical, 6)
                    } header: {
                        HStack(spacing: 6) {
                            Text(pack.name)
                            if !unlock.isUnlocked {
                                Image(systemName: "lock.fill").font(.caption2)
                            }
                        }
                    } footer: {
                        if pack.id == NewTabCatalog.packs.last?.id && !unlock.isUnlocked {
                            Text("Background packs are part of Zalla Unlock.")
                        }
                    }
                }

                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        Label(NewTabPhotoStore.exists ? "Choose a different photo" : "Choose a photo", systemImage: "photo")
                    }
                    if NewTabPhotoStore.exists {
                        Button {
                            storedValue = NewTabBackground.photo.storageValue
                        } label: {
                            HStack {
                                Label("Use my photo", systemImage: "photo.fill")
                                Spacer()
                                if current == .photo {
                                    Image(systemName: "checkmark").font(.body.weight(.semibold))
                                }
                            }
                        }
                        Button("Remove my photo", role: .destructive) {
                            NewTabPhotoStore.remove()
                            photoRevision += 1
                            if current == .photo { storedValue = NewTabBackground.standard.storageValue }
                        }
                    }
                    if let photoMessage {
                        Text(photoMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Your photo")
                } footer: {
                    Text("Your photo is resized and kept on this device. Zalla never uploads it.")
                }
            }
            .navigationTitle("New tab background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await importPhoto(item) }
            }
            .sheet(isPresented: $showUpsell) {
                ZallaUnlockSheet()
            }
        }
    }

    private var standardTile: some View {
        swatch(name: "Standard", selected: current == .standard, locked: false) {
            Color(uiColor: .systemGroupedBackground)
                .overlay(alignment: .top) {
                    RadialGradient(colors: [Color.accentColor.opacity(0.35), .clear], center: .top, startRadius: 4, endRadius: 90)
                }
        } action: {
            storedValue = NewTabBackground.standard.storageValue
        }
    }

    private func presetTile(_ preset: NewTabPreset) -> some View {
        let locked = preset.requiresUnlock && !unlock.isUnlocked
        return swatch(
            name: preset.name,
            selected: current == .preset(preset.id) && !locked,
            locked: locked
        ) {
            NewTabPresetFill(preset: preset)
        } action: {
            if locked {
                showUpsell = true
            } else {
                storedValue = NewTabBackground.preset(preset.id).storageValue
            }
        }
    }

    private func swatch<Fill: View>(
        name: String,
        selected: Bool,
        locked: Bool,
        @ViewBuilder fill: () -> Fill,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                fill()
                    .frame(height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 3 : 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.45), in: Circle())
                                .padding(6)
                        } else if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(6)
                        }
                    }
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(name), requires Zalla Unlock" : name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), NewTabPhotoStore.save(data) else {
            photoMessage = "That photo could not be used. Try a different one."
            return
        }
        photoMessage = nil
        photoRevision += 1
        storedValue = NewTabBackground.photo.storageValue
    }
}
