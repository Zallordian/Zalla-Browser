import SwiftUI

/// Settings > Privacy Shield. Every switch says in one line what it does and what it does not do.
struct PrivacyShieldView: View {
    @AppStorage(PrivacyShield.stripLinksKey) private var stripLinks = true
    @AppStorage(PrivacyShield.referrerKey) private var trimReferrer = true
    @AppStorage(PrivacyShield.fingerprintKey) private var fingerprint = false
    @AppStorage(PrivacyShield.encryptedDNSKey) private var encryptedDNS = false
    @AppStorage(PrivacyShield.dnsProviderKey) private var dnsProvider = DNSProvider.cloudflare.rawValue
    @AppStorage(PrivacyShield.proxyEnabledKey) private var proxyEnabled = false
    @AppStorage(PrivacyShield.proxyTypeKey) private var proxyType = ProxySettings.Kind.http.rawValue
    @AppStorage(PrivacyShield.proxyHostKey) private var proxyHost = ""
    @AppStorage(PrivacyShield.proxyPortKey) private var proxyPort = ""
    @State private var showDNSRestartNote = false

    var body: some View {
        Form {
            Section {
                shieldToggle(PrivacyShield.Copy.stripLinksTitle, PrivacyShield.Copy.stripLinksDetail, $stripLinks)
                shieldToggle(PrivacyShield.Copy.referrerTitle, PrivacyShield.Copy.referrerDetail, $trimReferrer)
                shieldToggle(PrivacyShield.Copy.fingerprintTitle, PrivacyShield.Copy.fingerprintDetail, $fingerprint)
            } header: {
                Text("On pages")
            }
            .onChange(of: stripLinks) { _, _ in scriptsChanged() }
            .onChange(of: trimReferrer) { _, _ in scriptsChanged() }
            .onChange(of: fingerprint) { _, _ in scriptsChanged() }

            Section {
                shieldToggle(PrivacyShield.Copy.encryptedDNSTitle, PrivacyShield.Copy.encryptedDNSDetail, $encryptedDNS)
                if encryptedDNS {
                    Picker("Provider", selection: $dnsProvider) {
                        ForEach(DNSProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }
                }
                if showDNSRestartNote {
                    Text("Restart Zalla for this change to take effect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Name lookups")
            }
            .onChange(of: encryptedDNS) { _, _ in showDNSRestartNote = true }
            .onChange(of: dnsProvider) { _, _ in showDNSRestartNote = true }

            Section {
                shieldToggle(PrivacyShield.Copy.proxyTitle, PrivacyShield.Copy.proxyDetail, $proxyEnabled)
                if proxyEnabled {
                    Picker("Type", selection: $proxyType) {
                        ForEach(ProxySettings.Kind.allCases) { kind in
                            Text(kind.rawValue).tag(kind.rawValue)
                        }
                    }
                    TextField("Proxy host", text: $proxyHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Port", text: $proxyPort)
                        .keyboardType(.numberPad)
                    Text(proxyStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Proxy")
            } footer: {
                Text("Applies to web pages you open in Zalla. Changing it can interrupt pages that are loading.")
            }
            .onChange(of: proxyEnabled) { _, _ in proxyChanged() }
            .onChange(of: proxyType) { _, _ in proxyChanged() }
            .onChange(of: proxyHost) { _, _ in proxyChanged() }
            .onChange(of: proxyPort) { _, _ in proxyChanged() }

            Section {
            } footer: {
                Text(PrivacyShield.Copy.footer)
            }
        }
        .navigationTitle("Privacy Shield")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var proxyStatus: String {
        let kind = ProxySettings.Kind(rawValue: proxyType) ?? .http
        if ProxySettings.validated(kind: kind, host: proxyHost, port: proxyPort) != nil {
            return "Web pages will go through this proxy."
        }
        return "Enter the proxy host and a port from 1 to 65535. Until then no proxy is used."
    }

    private func shieldToggle(_ title: String, _ detail: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scriptsChanged() {
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    private func proxyChanged() {
        NotificationCenter.default.post(name: .zallaProxyChanged, object: nil)
    }
}

/// Settings > Location. A city or town typed by the user, never read from the device.
struct LocationSettingsView: View {
    @AppStorage(LocationSettings.cityKey) private var city = ""
    @AppStorage(LocationSettings.searchKey) private var useInSearch = false
    @State private var draft = ""
    @State private var status: String?
    @State private var working = false
    @State private var sites: [String] = []

    var body: some View {
        Form {
            Section {
                TextField("City or town", text: $draft)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { Task { await save() } }
                Button {
                    Task { await save() }
                } label: {
                    if working {
                        ProgressView()
                    } else {
                        Text(city.isEmpty ? "Save city" : "Update city")
                    }
                }
                .disabled(working || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !city.isEmpty {
                    Button("Remove city", role: .destructive) {
                        LocationSettings.clear()
                        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
                        draft = ""
                        status = nil
                    }
                }
                if let status {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Your city")
            } footer: {
                Text("Optional and off by default. Your city is stored only on this device. Zalla does not use GPS or ask iOS for your location. Saving a city sends its name once to Apple Maps to find its center.")
            }

            Section {
                Toggle("Add my city to local searches", isOn: $useInSearch)
                    .disabled(city.isEmpty)
            } footer: {
                Text("Searches like \"pizza near me\" become \"pizza in\" plus your city. Your search engine sees the city you added.")
            }

            Section {
                if sites.isEmpty {
                    Text("No sites yet").foregroundStyle(.secondary)
                }
                ForEach(sites, id: \.self) { host in
                    Text(host)
                }
                .onDelete { offsets in
                    let list = sites
                    for offset in offsets where list.indices.contains(offset) {
                        LocationSettings.setShared(false, withHost: list[offset])
                    }
                    sites = LocationSettings.sites()
                }
            } header: {
                Text("Sites with your approximate location")
            } footer: {
                Text("Turn this on for a site from its page menu. It then sees the center of your city instead of your real location. Sites that use other ways to guess your location can still find you.")
            }
        }
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = city
            sites = LocationSettings.sites()
        }
    }

    private func save() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !working else { return }
        working = true
        defer { working = false }
        if let place = await LocationSettings.lookUpCenter(of: text) {
            LocationSettings.save(city: text, latitude: place.latitude, longitude: place.longitude)
            status = "Saved. Sites you allow will see the center of \(text)."
        } else {
            LocationSettings.save(city: text, latitude: nil, longitude: nil)
            status = "Saved for searches. Zalla could not find the center of that city, so it cannot share an approximate location with sites yet."
        }
    }
}

/// Page menu rows: share an approximate location with this site, and write CSS for it.
struct SiteToolsMenuRows: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject private var unlock = ZallaUnlock.shared
    @AppStorage(LocationSettings.cityKey) private var city = ""
    @State private var showUpsell = false
    @State private var showCSS = false
    @State private var shared = false

    var body: some View {
        if let host = tab.contentBlockingHost {
            if !city.isEmpty, LocationSettings.coordinate() != nil {
                Toggle(isOn: locationBinding(host: host)) {
                    Label("Share approximate location", systemImage: "location.circle")
                }
            }
            Button {
                if unlock.isUnlocked { showCSS = true } else { showUpsell = true }
            } label: {
                HStack {
                    Label("Site CSS", systemImage: "paintbrush")
                    Spacer()
                    if !unlock.isUnlocked {
                        Image(systemName: "lock.fill").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showUpsell) { ZallaUnlockSheet() }
            .sheet(isPresented: $showCSS) {
                NavigationStack { SiteCSSEditor(host: host, tab: tab) }
            }
        }
    }

    private func locationBinding(host: String) -> Binding<Bool> {
        Binding(
            get: { shared || LocationSettings.isShared(withHost: host) },
            set: { value in
                shared = value
                LocationSettings.setShared(value, withHost: host)
                tab.webView.reload()
            }
        )
    }
}

/// Editor for the CSS of one site.
struct SiteCSSEditor: View {
    let host: String
    @ObservedObject var tab: BrowserTab
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: 220)
            } header: {
                Text("CSS for \(host)")
            } footer: {
                Text("Runs only on \(host), on this device. Example: .banner { display: none !important; }")
            }
            if !SiteCSS.css(forHost: host).isEmpty {
                Section {
                    Button("Remove CSS for this site", role: .destructive) {
                        SiteCSS.set("", forHost: host)
                        tab.webView.reload()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Site CSS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    SiteCSS.set(text, forHost: host)
                    tab.webView.reload()
                    dismiss()
                }
            }
        }
        .onAppear { text = SiteCSS.css(forHost: host) }
    }
}
