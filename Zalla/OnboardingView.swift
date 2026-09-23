import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject var browser: BrowserStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @State private var step = 0
    @State private var pulse = false
    @State private var showImporter = false
    @State private var importMessage: String?

    private var theme: ZallaTheme { ZallaTheme.theme(forRaw: themeID) }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            theme.gradient.opacity(0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    if step > 0 {
                        Button("Back") { withAnimation { step -= 1 } }
                    }
                    Spacer()
                    if step > 0 {
                        Button("Skip") { finish() }
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $step) {
                    welcome.tag(0)
                    lookAndFeel.tag(1)
                    passwords.tag(2)
                    bookmarks.tag(3)
                    farewell.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: step)
            }
        }
        .tint(theme.primary)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.html],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Bookmarks", isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            Image("ZallaMark")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .scaleEffect(pulse ? 1.06 : 0.96)
                .shadow(color: theme.primary.opacity(0.35), radius: 24, y: 10)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            VStack(spacing: 10) {
                Text("Welcome to Zalla")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Built around you.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("A private browser that keeps your library on this device. No Zalla account. No built-in analytics.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)
            }
            Spacer()
            Button {
                withAnimation { step = 1 }
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }

    private var lookAndFeel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(title: "Look and feel", subtitle: "Choose how Zalla should feel on day one. You can change this anytime in Settings.")
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance").font(.headline)
                    Picker("Appearance", selection: $appearance) {
                        ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(20)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Search engine").font(.headline)
                    Picker("Search engine", selection: $searchEngine) {
                        ForEach(SearchEngine.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .pickerStyle(.menu)
                }
                .padding(20)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    Text("Accent theme").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 14)], spacing: 14) {
                        ForEach(ZallaThemeID.allCases) { id in
                            let swatch = ZallaTheme.theme(for: id)
                            Button {
                                themeID = id.rawValue
                            } label: {
                                Circle()
                                    .fill(swatch.gradient)
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        if themeID == id.rawValue {
                                            Image(systemName: "checkmark")
                                                .font(.headline.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .accessibilityLabel(id.displayName)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                nextButton("Continue") { step = 2 }
            }
            .padding(24)
        }
    }

    private var passwords: some View {
        VStack(alignment: .leading, spacing: 22) {
            header(
                title: "Passwords",
                subtitle: "Zalla uses Apple Passwords and iCloud Keychain AutoFill. There is no separate Zalla vault."
            )
            VStack(alignment: .leading, spacing: 14) {
                Label("Turn on AutoFill in Settings", systemImage: "key.fill")
                Text("Safari and Zalla can share the same saved passwords through Apple Passwords when AutoFill is enabled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    openPasswordSettings()
                } label: {
                    Text("Open password settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Spacer()
            nextButton("Continue") { step = 3 }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var bookmarks: some View {
        VStack(alignment: .leading, spacing: 22) {
            header(
                title: "Bring your bookmarks",
                subtitle: "Import an HTML bookmark file from Safari, Chrome, or Firefox. You can also skip and import later."
            )
            VStack(spacing: 12) {
                Button {
                    showImporter = true
                } label: {
                    Label("Import HTML bookmarks", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button("Skip for now") {
                    withAnimation { step = 4 }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Spacer()
            nextButton("Continue") { step = 4 }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var farewell: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(theme.gradient)
            VStack(spacing: 10) {
                Text("Enjoy your stay")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Your tabs, bookmarks, and history stay on this device. Have a great browse.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)
            }
            Spacer()
            Button(action: finish) {
                Text("Start browsing")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private func nextButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
    }

    private func finish() {
        hasCompletedOnboarding = true
    }

    private func openPasswordSettings() {
        let candidates = [
            "App-prefs:PASSWORDS",
            "App-prefs:Password",
            UIApplication.openSettingsURLString
        ]
        for raw in candidates {
            if let url = URL(string: raw), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let pages = BookmarkHTML.parse(text)
                let added = browser.importBookmarks(pages)
                importMessage = added == 0
                    ? "No new bookmarks were found in that file."
                    : "Imported \(added) bookmark\(added == 1 ? "" : "s")."
                withAnimation { step = 4 }
            } catch {
                importMessage = error.localizedDescription
            }
        }
    }
}
