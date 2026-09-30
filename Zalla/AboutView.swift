import SwiftUI

/// About Zalla: what protects you right now, what changed, and where to reach us.
struct AboutView: View {
    @ObservedObject private var unlock = ZallaUnlock.shared
    @State private var expandedBeta = false

    private var versionString: String {
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "14"
        return "\(marketing) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Zalla")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("Private by default. Beautiful by design.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                ForEach(SafetyOverview.items(unlocked: unlock.isUnlocked)) { item in
                    SafetyRow(item: item)
                }
            } header: {
                Text("Safety at a glance")
            } footer: {
                Text("Statuses update from your settings. Privacy Shield is not a VPN: it does not hide your IP address, and sites and your search engine still see the requests you make.")
            }

            Section("What's new") {
                ForEach(Changelog.releases) { entry in
                    ReleaseView(entry: entry)
                }
                DisclosureGroup("Before launch", isExpanded: $expandedBeta) {
                    ForEach(Changelog.beta) { entry in
                        ReleaseView(entry: entry)
                    }
                }
            }

            if AboutLinks.showsStory {
                Section("Our story") {
                    Text(AboutLinks.storyPlaceholder)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Version and contact") {
                LabeledContent("Version", value: versionString)
                Link(destination: AboutLinks.privacy) {
                    Label("Privacy Policy", systemImage: "doc.text")
                }
                Link(destination: AboutLinks.support) {
                    Label("Support", systemImage: "questionmark.circle")
                }
                Link(destination: AboutLinks.feedbackURL) {
                    Label("Send feedback: \(AboutLinks.feedbackEmail)", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("About Zalla")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SafetyRow: View {
    let item: SafetyItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.title).font(.body.weight(.semibold))
                Spacer(minLength: 8)
                Text(item.status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.isOn ? Color.green : Color.secondary)
            }
            Text(item.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct ReleaseView: View {
    let entry: ChangelogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.version).font(.headline)
                Text(entry.name).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(entry.highlights, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\u{2022}").foregroundStyle(.tint)
                    Text(line).fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
            }
            if !entry.improvements.isEmpty {
                (Text("Improvements: ").bold() + Text(entry.improvements))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !entry.fixes.isEmpty {
                (Text("Fixes: ").bold() + Text(entry.fixes))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
