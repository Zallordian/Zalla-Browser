import AVFoundation
import SwiftUI

// MARK: - Listen to page

/// Reads a page aloud with the system voice. Everything happens on this device.
@MainActor
final class PageSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum State: Equatable {
        case idle
        case speaking
        case paused
    }

    @Published private(set) var state: State = .idle
    /// The tab being read, so the controls only show on that tab and reading stops when you leave it.
    private(set) var tabID: UUID?
    private let synthesizer = AVSpeechSynthesizer()
    private var lastUtterance: ObjectIdentifier?

    var isActive: Bool { state != .idle }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start(tabID: UUID, title: String, paragraphs: [String]) {
        stop()
        let chunks = SpeechText.chunks(title: title, paragraphs: paragraphs)
        guard !chunks.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        self.tabID = tabID
        let language = Locale.preferredLanguages.first ?? "en-US"
        let voice = AVSpeechSynthesisVoice(language: language)
        for chunk in chunks {
            let utterance = AVSpeechUtterance(string: chunk)
            utterance.voice = voice
            lastUtterance = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        }
        state = .speaking
    }

    func pause() {
        guard state == .speaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        synthesizer.continueSpeaking()
        state = .speaking
    }

    func stop() {
        lastUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        state = .idle
        tabID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let finished = ObjectIdentifier(utterance)
        Task { @MainActor in
            if self.lastUtterance == finished { self.stop() }
        }
    }
}

/// Page menu rows for Listen to Page. Locked without Zalla Unlock.
struct ListenMenuRows: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var speaker: PageSpeaker
    @ObservedObject private var unlock = ZallaUnlock.shared
    let onDone: () -> Void
    @State private var showUpsell = false

    private var readingThisTab: Bool { speaker.isActive && speaker.tabID == tab.id }

    var body: some View {
        if readingThisTab {
            Button {
                if speaker.state == .paused { speaker.resume() } else { speaker.pause() }
            } label: {
                Label(
                    speaker.state == .paused ? "Resume listening" : "Pause listening",
                    systemImage: speaker.state == .paused ? "play.fill" : "pause.fill"
                )
            }
            Button(role: .destructive) {
                speaker.stop()
            } label: {
                Label("Stop listening", systemImage: "stop.fill")
            }
        } else {
            Button {
                if unlock.isUnlocked {
                    tab.listen(using: speaker)
                    onDone()
                } else {
                    showUpsell = true
                }
            } label: {
                HStack {
                    Label("Listen to page", systemImage: "speaker.wave.2")
                    Spacer()
                    if !unlock.isUnlocked {
                        Image(systemName: "lock.fill").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!tab.hasPage)
            .sheet(isPresented: $showUpsell) { ZallaUnlockSheet() }
        }
    }
}

// MARK: - Face ID lock screen

/// Covers a locked private tab until Face ID (or the passcode) succeeds.
struct PrivateLockView: View {
    @ObservedObject var browser: BrowserStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var asked = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.tint)
                Text("Private tab locked")
                    .font(.title3.weight(.semibold))
                Text("Unlock with Face ID or your passcode to see your private tabs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    Task { await browser.unlockPrivateTabs() }
                } label: {
                    Label("Unlock", systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                if let regular = browser.tabs.last(where: { !$0.isPrivate }) {
                    Button("Switch to a regular tab") { browser.selectTab(regular) }
                        .font(.subheadline)
                }
                Button("Close private tabs", role: .destructive) {
                    browser.closePrivateTabs()
                }
                .font(.subheadline)
            }
        }
        .task(id: scenePhase) {
            // Ask once each time Zalla comes back to the front. The Face ID prompt itself briefly makes
            // the app inactive, which must not trigger another prompt.
            if scenePhase == .background {
                asked = false
            } else if scenePhase == .active, !asked {
                asked = true
                await browser.unlockPrivateTabs()
            }
        }
    }
}

// MARK: - Settings rows

/// Face ID for private tabs, plus the link to scheduled auto-clear.
struct PremiumPrivacyRows: View {
    @ObservedObject private var unlock = ZallaUnlock.shared
    @AppStorage(PrivateTabLock.storageKey) private var faceID = false
    @AppStorage(AutoClear.scheduleKey) private var scheduleRaw = AutoClearSchedule.off.rawValue
    @State private var showUpsell = false
    @State private var message: String?

    var body: some View {
        Toggle(isOn: faceIDBinding) {
            HStack {
                Label("Face ID for private tabs", systemImage: "faceid")
                if !unlock.isUnlocked {
                    Image(systemName: "lock.fill").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        if let message {
            Text(message).font(.footnote).foregroundStyle(.secondary)
        }
        NavigationLink {
            AutoClearSettingsView()
        } label: {
            HStack {
                Label("Auto-clear", systemImage: "clock.arrow.circlepath")
                if !unlock.isUnlocked {
                    Image(systemName: "lock.fill").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Text(unlock.isUnlocked ? scheduleRaw : "Off")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showUpsell) { ZallaUnlockSheet() }
    }

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { faceID && unlock.isUnlocked },
            set: { value in
                message = nil
                guard unlock.isUnlocked else {
                    showUpsell = true
                    return
                }
                guard value else {
                    faceID = false
                    return
                }
                guard PrivateTabLock.canAuthenticate() else {
                    message = "Set a passcode or Face ID on this device to lock private tabs."
                    return
                }
                Task {
                    // Prove it works before turning it on, so nobody gets locked out of their own tabs.
                    if await PrivateTabLock.authenticate(reason: "Turn on Face ID for private tabs") {
                        faceID = true
                    }
                }
            }
        )
    }
}

/// Scheduled auto-clear: history and website data on launch, daily, or weekly.
struct AutoClearSettingsView: View {
    @ObservedObject private var unlock = ZallaUnlock.shared
    @AppStorage(AutoClear.scheduleKey) private var scheduleRaw = AutoClearSchedule.off.rawValue
    @AppStorage(AutoClear.historyKey) private var clearHistory = true
    @AppStorage(AutoClear.siteDataKey) private var clearSiteData = true
    @AppStorage(AutoClear.lastRunKey) private var lastRun = 0.0
    @State private var showUpsell = false

    var body: some View {
        Form {
            if !unlock.isUnlocked {
                Section {
                    Button {
                        showUpsell = true
                    } label: {
                        Label("Auto-clear is part of Zalla Unlock", systemImage: "lock.fill")
                    }
                }
            }
            Section {
                Picker("Clear", selection: $scheduleRaw) {
                    ForEach(AutoClearSchedule.allCases) { schedule in
                        Text(schedule.rawValue).tag(schedule.rawValue)
                    }
                }
                Toggle("Browsing history", isOn: $clearHistory)
                Toggle("Cookies and website data", isOn: $clearSiteData)
            } header: {
                Text("Schedule")
            } footer: {
                Text("Zalla checks when it opens and when you come back to it. Bookmarks, downloads, and settings are never cleared. Clearing cookies signs you out of websites.")
            }
            .disabled(!unlock.isUnlocked)
            if unlock.isUnlocked, lastRun > 0 {
                Section {
                    LabeledContent("Last cleared") {
                        Text(Date(timeIntervalSince1970: lastRun), format: .dateTime.month().day().hour().minute())
                    }
                }
            }
        }
        .navigationTitle("Auto-clear")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scheduleRaw) { _, newValue in
            // Start the clock when an interval is chosen, so switching it on never wipes anything immediately.
            if AutoClearSchedule(rawValue: newValue)?.interval != nil {
                AutoClear.recordRun()
            }
        }
        .sheet(isPresented: $showUpsell) { ZallaUnlockSheet() }
    }
}

// MARK: - Tab groups

/// Group chips above the tab grid. Nil selection means all tabs.
struct TabGroupBar: View {
    @ObservedObject var browser: BrowserStore
    @Binding var filter: UUID?
    let onNewGroup: () -> Void
    let onEdit: (TabGroup) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", color: nil, selected: filter == nil) { filter = nil }
                ForEach(browser.groups) { group in
                    chip(title: group.name, color: group.color.color, selected: filter == group.id) {
                        filter = group.id
                    }
                    .contextMenu {
                        Button { onEdit(group) } label: { Label("Edit group", systemImage: "pencil") }
                    }
                }
                Button(action: onNewGroup) {
                    Label("New group", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(title: String, color: Color?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let color {
                    Circle().fill(color).frame(width: 10, height: 10)
                }
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.08), in: Capsule())
            .overlay { Capsule().stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Create or edit a tab group: name, color, and delete.
struct TabGroupEditor: View {
    @ObservedObject var browser: BrowserStore
    /// Nil creates a new group.
    let group: TabGroup?
    /// Called with the new group after creating, so the caller can add a tab to it.
    var onCreated: ((TabGroup) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color = TabGroupColor.blue

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Group name", text: $name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { _, value in
                            if value.count > TabGroupStore.maxNameLength {
                                name = String(value.prefix(TabGroupStore.maxNameLength))
                            }
                        }
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
                        ForEach(TabGroupColor.allCases) { option in
                            Button {
                                color = option
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if option == color {
                                            Image(systemName: "checkmark").font(.footnote.bold()).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.title)
                            .accessibilityAddTraits(option == color ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let group {
                    Section {
                        Button("Delete group", role: .destructive) {
                            browser.deleteGroup(group)
                            dismiss()
                        }
                    } footer: {
                        Text("Tabs in the group stay open.")
                    }
                }
            }
            .navigationTitle(group == nil ? "New group" : "Edit group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let group {
                            browser.updateGroup(group, name: name, color: color)
                        } else if let created = browser.createGroup(name: name, color: color) {
                            onCreated?(created)
                        }
                        dismiss()
                    }
                    .disabled(TabGroupStore.cleanedName(name) == nil)
                }
            }
            .onAppear {
                if let group {
                    name = group.name
                    color = group.color
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Long-press menu entries for moving one tab between groups.
struct TabGroupMenu: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    let onNewGroup: () -> Void

    var body: some View {
        if !tab.isPrivate {
            Menu {
                ForEach(browser.groups) { group in
                    Button {
                        browser.assign(tab, to: group)
                    } label: {
                        if tab.groupID == group.id {
                            Label(group.name, systemImage: "checkmark")
                        } else {
                            Text(group.name)
                        }
                    }
                }
                Button(action: onNewGroup) { Label("New group", systemImage: "plus") }
                if tab.groupID != nil {
                    Button(role: .destructive) {
                        browser.assign(tab, to: nil)
                    } label: { Label("Remove from group", systemImage: "minus.circle") }
                }
            } label: {
                Label("Add to group", systemImage: "rectangle.stack.badge.plus")
            }
        }
    }
}
