import SwiftUI

/// The privacy report card: what Zalla did for you, overall and for the site you are on.
struct PrivacyReportView: View {
    @ObservedObject var tab: BrowserTab
    @State private var store = PrivacyReport.load()
    @State private var thirdParties: [String] = []
    @State private var measured = false
    @State private var confirmReset = false
    @ObservedObject private var blocker = ContentBlocker.shared

    private var host: String? { PrivacyReport.siteKey(tab.hasPage ? (tab.webView.url ?? tab.url)?.host : nil) }

    private var blockingIsOn: Bool {
        guard blocker.settings.isEnabled, let key = tab.contentBlockingHost else { return false }
        return blocker.isBlockingOn(forHost: key)
    }

    var body: some View {
        List {
            if let host {
                Section {
                    protectionRow(title: "Tracker and ad blocking", on: blockingIsOn)
                    protectionRow(title: "Secure connection", on: tab.hasOnlySecureContent)
                    countRow("Tracking tags cleaned from links", PrivacyReport.counts(forHost: host).linkCleaned)
                    countRow("Upgraded to HTTPS", PrivacyReport.counts(forHost: host).httpsUpgrade)
                    countRow("Cookie banners closed", PrivacyReport.counts(forHost: host).cookieBannerDismissed)
                } header: {
                    Text(host)
                        .textCase(nil)
                }
                Section {
                    if !measured {
                        Text("Measuring...").foregroundStyle(.secondary)
                    } else if thirdParties.isEmpty {
                        Text("None seen on this page.").foregroundStyle(.secondary)
                    } else {
                        ForEach(thirdParties.prefix(30), id: \.self) { name in
                            Text(name).font(.footnote)
                        }
                        if thirdParties.count > 30 {
                            Text("and \(thirdParties.count - 30) more").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Other sites this page contacted")
                } footer: {
                    Text("These got through. Anything Zalla's blocker stopped never connected, so it does not show up here, and Zalla does not get a count from it.")
                }
            } else {
                Section {
                    Text("Open a page and this shows what Zalla is doing on it.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                countRow("Tracking tags cleaned from links", store.overall.linkCleaned)
                countRow("Upgraded to HTTPS", store.overall.httpsUpgrade)
                countRow("Cookie banners closed", store.overall.cookieBannerDismissed)
            } header: {
                Text("Since you started")
            } footer: {
                Text("Counted on this device only. Private tabs are never counted. Trackers and ads stopped by the blocker are not counted, because Apple's blocker does not report them.")
            }

            Section {
                Button("Reset the report", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Privacy report")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            store = PrivacyReport.load()
            thirdParties = await tab.thirdPartyHostsOnPage()
            measured = true
        }
        .confirmationDialog("Reset the privacy report?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                PrivacyReport.reset()
                store = PrivacyReport.load()
            }
        }
    }

    private func protectionRow(title: String, on: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(on ? "On" : "Off", systemImage: on ? "checkmark.circle.fill" : "minus.circle")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(on ? Color.green : Color.secondary)
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private func countRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
