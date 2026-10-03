import SwiftUI

/// The Menu row for Video Saver. Shown only when the page offers a video file or stream, or its player is protected.
/// Without Zalla Unlock it shows a lock and opens the Unlock sheet.
struct VideoSaverMenuRow: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var browser: BrowserStore
    @Binding var sheet: BrowserSheet?
    @ObservedObject private var unlock = ZallaUnlock.shared
    @AppStorage(VideoSaver.storageKey) private var enabled = VideoSaver.defaultEnabled
    @State private var showUpsell = false

    private var availability: VideoSaver.Availability {
        VideoSaver.availability(for: VideoSaver.Report(candidates: tab.videoCandidates, protectedMedia: tab.videoProtected))
    }

    var body: some View {
        if enabled, availability != .none {
            if unlock.isUnlocked {
                NavigationLink {
                    VideoSaverView(tab: tab, browser: browser, sheet: $sheet)
                } label: {
                    Label("Save video", systemImage: "arrow.down.to.line")
                }
            } else {
                Button {
                    showUpsell = true
                } label: {
                    HStack {
                        Label("Save video", systemImage: "arrow.down.to.line")
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHint("Needs Zalla Unlock")
                .sheet(isPresented: $showUpsell) { ZallaUnlockSheet() }
            }
        }
    }
}

/// The videos this page offers, with a Save button for each file. Progress and sharing live in Downloads.
struct VideoSaverView: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var browser: BrowserStore
    @Binding var sheet: BrowserSheet?

    private func record(for candidate: VideoSaver.Candidate) -> DownloadRecord? {
        browser.downloads.first { $0.sourceURL == candidate.url }
    }

    var body: some View {
        List {
            if tab.videoCandidates.isEmpty {
                Section {
                    Text(tab.videoProtected ? VideoSaver.protectedMessage : VideoSaver.noVideoMessage)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(tab.videoCandidates) { candidate in
                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(candidate.url.host ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack {
                        status(for: candidate)
                        Spacer()
                        Button(candidate.kind == .file ? "Save" : "Check stream") {
                            tab.saveVideo(candidate)
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 2)
            }
            if tab.videoProtected, !tab.videoCandidates.isEmpty {
                Section {
                    Text("Part of this page uses protected video. That part can't be saved.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button {
                    sheet = .downloads
                } label: {
                    Label("Open Downloads", systemImage: "arrow.down.circle")
                }
            } footer: {
                Text("Saved videos land in Downloads, where you can open them or share them to Photos and Files. Zalla only saves video files a page serves plainly. Protected video and streams that need a key are never saved.")
            }
        }
        .navigationTitle("Save video")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func status(for candidate: VideoSaver.Candidate) -> some View {
        if let found = record(for: candidate) {
            switch found.state {
            case .downloading:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Saving").font(.caption).foregroundStyle(.secondary)
                }
            case .completed:
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .failed:
                Text("Could not save").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text(candidate.kind == .file ? "Video file" : "Stream")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
