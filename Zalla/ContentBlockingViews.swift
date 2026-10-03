import StoreKit
import SwiftUI

/// Filter lists bundled with Zalla and the license each is used under.
enum BlocklistCredits {
    struct Credit: Identifiable {
        let name: String
        let usage: String
        let authors: String
        let license: String
        let homepage: URL
        let licenseURL: URL
        var id: String { name }
    }

    static let all: [Credit] = [
        Credit(
            name: "EasyPrivacy",
            usage: "Block Trackers",
            authors: "The EasyList authors",
            license: "Creative Commons Attribution-ShareAlike 3.0",
            homepage: URL(string: "https://easylist.to/")!,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/3.0/")!
        ),
        Credit(
            name: "EasyList",
            usage: "Block Common Ads, Full Ad Blocking, Hide Ad Spaces",
            authors: "The EasyList authors",
            license: "Creative Commons Attribution-ShareAlike 3.0",
            homepage: URL(string: "https://easylist.to/")!,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/3.0/")!
        ),
        Credit(
            name: "EasyList Cookie List",
            usage: "Block Cookie Banners and Annoyances",
            authors: "The EasyList authors",
            license: "Creative Commons Attribution-ShareAlike 3.0",
            homepage: URL(string: "https://easylist.to/")!,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/3.0/")!
        ),
        Credit(
            name: "Fanboy's Annoyance List",
            usage: "Block Cookie Banners and Annoyances",
            authors: "Fanboy and the EasyList authors",
            license: "Creative Commons Attribution-ShareAlike 3.0",
            homepage: URL(string: "https://easylist.to/")!,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/3.0/")!
        )
    ]

    static let note = "Zalla converts these lists into Safari content blocker rules. The converted rule files are shared under the same license. Zalla is not affiliated with or endorsed by the list authors."
}

/// Settings > Privacy > Content Blocking.
struct ContentBlockingView: View {
    @ObservedObject private var blocker = ContentBlocker.shared
    @ObservedObject private var unlock = ZallaUnlock.shared
    @State private var showUpsell = false

    var body: some View {
        List {
            Section {
                Toggle("Content Blocking", isOn: masterBinding)
            } footer: {
                Text(statusText)
            }
            Section("Included") {
                ForEach(BlocklistCategory.allCases.filter { !$0.requiresUnlock }) { category in
                    BlocklistCategoryToggle(category: category, blocker: blocker)
                }
                NavigationLink {
                    AllowedSitesView()
                } label: {
                    CountRow(title: "Sites with Blocking Off", systemImage: "checkmark.shield", count: blocker.settings.allowedHosts.count)
                }
            }
            UnlockFeaturesSection(blocker: blocker, unlock: unlock, showUpsell: $showUpsell)
            Section {
                NavigationLink("Acknowledgements") {
                    AcknowledgementsView()
                }
            }
        }
        .navigationTitle("Content Blocking")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUpsell) {
            ZallaUnlockSheet()
        }
    }

    private var masterBinding: Binding<Bool> {
        Binding(
            get: { blocker.settings.isEnabled },
            set: { value in blocker.update { $0.isEnabled = value } }
        )
    }

    private var statusText: String {
        let base = "Blocks trackers and ads using Safari content blocker rules, on this device only. Turn blocking off for one site from the page menu. Changes apply to pages you open or reload."
        switch blocker.status {
        case .compiling:
            return "Preparing block lists. Pages keep loading meanwhile. " + base
        case .failed:
            return "Some block lists could not be prepared. They will be tried again next launch. " + base
        case .idle, .ready:
            return base
        }
    }
}

private struct UnlockFeaturesSection: View {
    @ObservedObject var blocker: ContentBlocker
    @ObservedObject var unlock: ZallaUnlock
    @Binding var showUpsell: Bool

    var body: some View {
        Section {
            ForEach(BlocklistCategory.allCases.filter(\.requiresUnlock)) { category in
                if unlock.isUnlocked {
                    BlocklistCategoryToggle(category: category, blocker: blocker)
                } else {
                    LockedFeatureRow(title: category.title, systemImage: category.systemImage) { showUpsell = true }
                }
            }
            if unlock.isUnlocked {
                NavigationLink {
                    HiddenElementsView()
                } label: {
                    CountRow(title: "Hidden Elements", systemImage: "eye.slash.circle", count: blocker.settings.hiddenElements.count)
                }
                NavigationLink {
                    CustomRulesView()
                } label: {
                    Label("Custom Rules", systemImage: "list.bullet.rectangle")
                }
            } else {
                LockedFeatureRow(title: "Hide Element", systemImage: "eye.slash.circle") { showUpsell = true }
                LockedFeatureRow(title: "Custom Rules", systemImage: "list.bullet.rectangle") { showUpsell = true }
            }
        } header: {
            Text(ZallaUnlockProduct.Copy.title)
        } footer: {
            if !unlock.isUnlocked {
                Button("Learn about Zalla Unlock") { showUpsell = true }
                    .font(.footnote.weight(.semibold))
            }
        }
    }
}

private struct BlocklistCategoryToggle: View {
    let category: BlocklistCategory
    @ObservedObject var blocker: ContentBlocker

    var body: some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Label(category.title, systemImage: category.systemImage)
                Text(category.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!blocker.settings.isEnabled)
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { blocker.settings.isOn(category) },
            set: { value in blocker.update { $0.set(category, on: value) } }
        )
    }
}

private struct LockedFeatureRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHint("Requires Zalla Unlock")
    }
}

private struct CountRow: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer(minLength: 8)
            if count > 0 {
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Sites where Blocking on this Site is off. Free, since it only lists choices made per site.
struct AllowedSitesView: View {
    @ObservedObject private var blocker = ContentBlocker.shared

    var body: some View {
        List {
            Section {
                if blocker.settings.allowedHosts.isEmpty {
                    Text("No sites yet. Turn off Blocking on this Site from the page menu to add one.")
                        .foregroundStyle(.secondary)
                }
                ForEach(blocker.settings.allowedHosts, id: \.self) { host in
                    Text(host)
                }
                .onDelete { offsets in
                    blocker.update { $0.allowedHosts.remove(atOffsets: offsets) }
                }
            } footer: {
                Text("Blocking is off on these sites and their subdomains. Swipe to turn it back on.")
            }
        }
        .navigationTitle("Sites with Blocking Off")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Elements hidden with Hide Element, grouped by site.
struct HiddenElementsView: View {
    @ObservedObject private var blocker = ContentBlocker.shared

    private var hosts: [String] {
        Array(Set(blocker.settings.hiddenElements.map(\.host))).sorted()
    }

    var body: some View {
        List {
            if hosts.isEmpty {
                Text("Nothing hidden yet. Open the menu on any page and choose Hide Element, then tap what you want gone.")
                    .foregroundStyle(.secondary)
            }
            ForEach(hosts, id: \.self) { host in
                HiddenElementsSection(host: host, blocker: blocker)
            }
        }
        .navigationTitle("Hidden Elements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HiddenElementsSection: View {
    let host: String
    @ObservedObject var blocker: ContentBlocker

    private var rules: [HiddenElementRule] {
        blocker.settings.hiddenElements.filter { $0.host == host }
    }

    var body: some View {
        Section(host) {
            ForEach(rules) { rule in
                Text(rule.selector)
                    .font(.footnote.monospaced())
                    .lineLimit(2)
            }
            .onDelete { offsets in
                let ids = Set(offsets.map { rules[$0].id })
                blocker.update { settings in
                    settings.hiddenElements.removeAll { ids.contains($0.id) }
                }
            }
        }
    }
}

/// Always Block and Always Allow lists (Zalla Unlock).
struct CustomRulesView: View {
    @ObservedObject private var blocker = ContentBlocker.shared
    @State private var newBlock = ""
    @State private var newAllow = ""
    @State private var invalidEntry = false

    var body: some View {
        List {
            Section {
                AddHostField(placeholder: "ads.example.com", text: $newBlock) { addBlock() }
                ForEach(blocker.settings.customBlockedHosts, id: \.self) { host in
                    Text(host)
                }
                .onDelete { offsets in
                    blocker.update { $0.customBlockedHosts.remove(atOffsets: offsets) }
                }
            } header: {
                Text("Always Block")
            } footer: {
                Text("Requests to these sites and their subdomains are blocked on every page.")
            }
            Section {
                AddHostField(placeholder: "example.com", text: $newAllow) { addAllow() }
                ForEach(blocker.settings.allowedHosts, id: \.self) { host in
                    Text(host)
                }
                .onDelete { offsets in
                    blocker.update { $0.allowedHosts.remove(atOffsets: offsets) }
                }
            } header: {
                Text("Always Allow")
            } footer: {
                Text("Blocking is off on these sites and their subdomains.")
            }
        }
        .navigationTitle("Custom Rules")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Enter a site like example.com.", isPresented: $invalidEntry) {
            Button("OK", role: .cancel) {}
        }
    }

    private func addBlock() {
        var added = false
        blocker.update { added = $0.addCustomBlock(fromUserInput: newBlock) }
        if added || ContentBlockingSettings.normalizedHost(fromUserInput: newBlock) != nil {
            newBlock = ""
        } else {
            invalidEntry = true
        }
    }

    private func addAllow() {
        var added = false
        blocker.update { added = $0.addAllowedHost(fromUserInput: newAllow) }
        if added || ContentBlockingSettings.normalizedHost(fromUserInput: newAllow) != nil {
            newAllow = ""
        } else {
            invalidEntry = true
        }
    }
}

private struct AddHostField: View {
    let placeholder: String
    @Binding var text: String
    let onAdd: () -> Void

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.done)
                .onSubmit(onAdd)
            Button("Add", action: onAdd)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

/// Credits for the bundled filter lists.
struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                Text(BlocklistCredits.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(BlocklistCredits.all) { credit in
                CreditSection(credit: credit)
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CreditSection: View {
    let credit: BlocklistCredits.Credit

    var body: some View {
        Section(credit.name) {
            LabeledContent("Used for", value: credit.usage)
            LabeledContent("Authors", value: credit.authors)
            Link(destination: credit.licenseURL) {
                Label(credit.license, systemImage: "doc.text")
            }
            Link(destination: credit.homepage) {
                Label("easylist.to", systemImage: "safari")
            }
        }
    }
}

/// Upsell for Zalla Unlock. The price always comes from StoreKit.
struct ZallaUnlockSheet: View {
    @ObservedObject private var unlock = ZallaUnlock.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    UnlockHeader()
                }
                Section("Includes") {
                    ForEach(BlocklistCategory.allCases.filter(\.requiresUnlock)) { category in
                        Label(category.title, systemImage: category.systemImage)
                    }
                    Label("Hide Element on any site", systemImage: "eye.slash.circle")
                    Label("Custom block and allow rules", systemImage: "list.bullet.rectangle")
                    Label("Face ID for private tabs", systemImage: "faceid")
                    Label("Tab groups", systemImage: "rectangle.stack")
                    // Grouped so the list stays within the ten rows a ViewBuilder block allows.
                    Group {
                        Label("Listen to page", systemImage: "speaker.wave.2")
                        Label("Video Saver for plain video files", systemImage: "arrow.down.to.line")
                    }
                    Label("Per-site CSS", systemImage: "paintbrush")
                    Label("Scheduled auto-clear", systemImage: "clock.arrow.circlepath")
                    Label("Background packs for new tabs", systemImage: "photo.on.rectangle.angled")
                    Label("Space, Jungle, Volcano, Deep Ocean, Retro Arcade, Neon City, Arctic, and Cherry Blossom theme packs, with matching icons and full-screen transitions", systemImage: "sparkles")
                }
                Section {
                    UnlockPurchaseRow(unlock: unlock)
                    Button("Restore Purchases") {
                        Task { await unlock.restore() }
                    }
                    .disabled(unlock.isBusy)
                } footer: {
                    Text(footerText)
                }
            }
            .navigationTitle(ZallaUnlockProduct.Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await unlock.loadProduct() }
        }
    }

    private var footerText: String {
        switch unlock.purchaseState {
        case .pending:
            return ZallaUnlockProduct.Copy.pending
        case .failed(let message), .message(let message):
            return message
        case .idle, .purchasing, .restoring:
            return "Blocking trackers and common ads, Privacy Shield, and image export stay free. Payments are handled by Apple."
        }
    }
}

private struct UnlockHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(ZallaUnlockProduct.Copy.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(ZallaUnlockProduct.Copy.subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(ZallaUnlockProduct.Copy.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct UnlockPurchaseRow: View {
    @ObservedObject var unlock: ZallaUnlock

    var body: some View {
        if unlock.isUnlocked {
            Label(ZallaUnlockProduct.Copy.unlocked, systemImage: "checkmark.seal.fill")
                .foregroundStyle(.tint)
        } else {
            switch unlock.loadState {
            case .idle, .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            case .unavailable:
                Text(ZallaUnlockProduct.Copy.unavailable)
                    .foregroundStyle(.secondary)
            case .loaded:
                buyButton
            }
        }
    }

    private var buyButton: some View {
        Button {
            Task { await unlock.purchase() }
        } label: {
            HStack {
                Text("Unlock")
                    .font(.headline)
                Spacer()
                if unlock.purchaseState == .purchasing {
                    ProgressView()
                } else {
                    Text(unlock.product?.displayPrice ?? "")
                        .font(.headline)
                }
            }
        }
        .disabled(unlock.isBusy || unlock.product == nil)
    }
}

/// Blocking on this Site and Hide Element rows for the page menu.
struct SiteBlockingMenuRows: View {
    @ObservedObject var tab: BrowserTab
    let onDone: () -> Void
    @ObservedObject private var blocker = ContentBlocker.shared
    @ObservedObject private var unlock = ZallaUnlock.shared
    @State private var showUpsell = false

    var body: some View {
        if let host = tab.contentBlockingHost {
            Toggle(isOn: siteBinding(host: host)) {
                Label("Blocking on this Site", systemImage: "shield.lefthalf.filled")
            }
            .disabled(!blocker.settings.isEnabled)
            Button {
                if unlock.isUnlocked {
                    onDone()
                    tab.beginElementPicker()
                } else {
                    showUpsell = true
                }
            } label: {
                HStack {
                    Label("Hide Element", systemImage: "eye.slash.circle")
                    Spacer()
                    if !unlock.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showUpsell) {
                ZallaUnlockSheet()
            }
        }
    }

    private func siteBinding(host: String) -> Binding<Bool> {
        Binding(
            get: { blocker.settings.isEnabled && blocker.isBlockingOn(forHost: host) },
            set: { value in tab.setContentBlockingForSite(value) }
        )
    }
}
