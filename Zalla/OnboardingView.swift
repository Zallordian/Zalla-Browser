import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject var browser: BrowserStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage(ToolbarStyle.storageKey) private var toolbarStyleRaw = ToolbarStyle.classic.rawValue
    @AppStorage(AddressBarPlacement.storageKey) private var addressBarPlacementRaw = AddressBarPlacement.bottom.rawValue
    @State private var step = 0
    @State private var pulse = false
    @State private var glowSpin = false
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var contentVisible = true
    @State private var farewellBurst = false
    @State private var washAngle: Double = 0

    private var theme: ZallaTheme { ZallaTheme.theme(forRaw: themeID) }

    private var preferredScheme: ColorScheme? {
        appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil
    }

    private var previewIsDark: Bool {
        switch appearance {
        case "Dark": return true
        case "Light": return false
        default: return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }

    var body: some View {
        ZStack {
            animatedBackground

            VStack(spacing: 0) {
                HStack {
                    if step > 0 {
                        Button("Back") { goTo(step - 1) }
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
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
            }
        }
        .tint(theme.primary)
        .preferredColorScheme(preferredScheme)
        .animation(.easeInOut(duration: 0.35), value: appearance)
        .animation(.easeInOut(duration: 0.35), value: themeID)
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                washAngle = 360
            }
        }
        .onChange(of: step) { _, _ in
            contentVisible = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                contentVisible = true
            }
            if step == 4 {
                farewellBurst = false
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.05)) {
                    farewellBurst = true
                }
            }
        }
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

    // MARK: - Background

    private var animatedBackground: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            AngularGradient(
                colors: [
                    theme.primary.opacity(0.22),
                    theme.bright.opacity(0.10),
                    theme.gradientEnd.opacity(0.18),
                    theme.deep.opacity(0.08),
                    theme.primary.opacity(0.22)
                ],
                center: .center,
                angle: .degrees(washAngle)
            )
            .blur(radius: 48)
            .opacity(0.85)
            .ignoresSafeArea()
            .scaleEffect(1.35)

            LinearGradient(
                colors: [
                    theme.primary.opacity(0.16),
                    Color.clear,
                    theme.gradientEnd.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.9)
            .ignoresSafeArea()
            .rotationEffect(.degrees(washAngle * 0.08))
            .scaleEffect(1.2)
        }
        .animation(.easeInOut(duration: 0.45), value: themeID)
        .animation(.easeInOut(duration: 0.45), value: appearance)
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [theme.primary.opacity(0.45), theme.bright.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .blur(radius: 6)

                Circle()
                    .strokeBorder(theme.gradient, lineWidth: 2)
                    .frame(width: 148, height: 148)
                    .rotationEffect(.degrees(glowSpin ? 360 : 0))
                    .opacity(0.55)

                Image("ZallaMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .scaleEffect(pulse ? 1.06 : 0.96)
                    .offset(y: pulse ? -2 : 2)
                    .shadow(color: theme.primary.opacity(0.35), radius: 24, y: 10)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                    glowSpin = true
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
            .opacity(contentVisible || step != 0 ? 1 : 0)
            .offset(y: contentVisible || step != 0 ? 0 : 16)

            Spacer()
            Button {
                goTo(1)
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
            .scaleEffect(pulse ? 1.01 : 1.0)
        }
    }

    private var lookAndFeel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    title: "Look and feel",
                    subtitle: "Zalla starts with a bottom address bar and Classic toolbar. Compact stays off unless you turn it on later in Settings."
                )

                miniBrowserPreview
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance").font(.headline)
                    Picker("Appearance", selection: appearanceBinding) {
                        ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(20)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Search engine").font(.headline)
                    Picker("Search engine", selection: $searchEngine) {
                        ForEach(SearchEngine.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .pickerStyle(.menu)
                }
                .padding(20)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Browser chrome").font(.headline)
                    Text("Defaults match daily browsing. You can try Compact later without changing anything now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Toolbar", selection: $toolbarStyleRaw) {
                        ForEach(ToolbarStyle.allCases) { style in
                            Text(style.rawValue).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Address bar", selection: $addressBarPlacementRaw) {
                        ForEach(AddressBarPlacement.allCases) { placement in
                            Text(placement.rawValue).tag(placement.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(20)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Accent theme").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 14)], spacing: 14) {
                        ForEach(ZallaThemeID.allCases) { id in
                            let swatch = ZallaTheme.theme(for: id)
                            let selected = themeID == id.rawValue
                            Button {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                                    themeID = id.rawValue
                                }
                            } label: {
                                Circle()
                                    .fill(swatch.gradient)
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        if selected {
                                            Image(systemName: "checkmark")
                                                .font(.headline.bold())
                                                .foregroundStyle(.white)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    .scaleEffect(selected ? 1.12 : 1.0)
                                    .shadow(color: selected ? swatch.primary.opacity(0.45) : .clear, radius: 10, y: 4)
                                    .accessibilityLabel(id.displayName)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .background(cardBackground)

                nextButton("Continue") { goTo(2) }
            }
            .padding(24)
            .opacity(step == 1 && !contentVisible ? 0 : 1)
            .offset(y: step == 1 && !contentVisible ? 18 : 0)
        }
    }

    private var passwords: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepHero(systemName: "key.fill")
            header(
                title: "Passwords",
                subtitle: "Zalla uses Apple Passwords and iCloud Keychain AutoFill. There is no separate Zalla vault."
            )
            VStack(alignment: .leading, spacing: 14) {
                Label("Turn on AutoFill in Settings", systemImage: "key.fill")
                    .font(.headline)
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
            .background(cardBackground)
            Spacer()
            nextButton("Continue") { goTo(3) }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .opacity(step == 2 && !contentVisible ? 0 : 1)
        .offset(y: step == 2 && !contentVisible ? 18 : 0)
    }

    private var bookmarks: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepHero(systemName: "bookmark.fill")
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
                    goTo(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .padding(20)
            .background(cardBackground)
            Spacer()
            nextButton("Continue") { goTo(4) }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .opacity(step == 3 && !contentVisible ? 0 : 1)
        .offset(y: step == 3 && !contentVisible ? 18 : 0)
    }

    private var farewell: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: sparkleNames[index % sparkleNames.count])
                        .font(.system(size: farewellBurst ? 18 : 10, weight: .semibold))
                        .foregroundStyle(theme.primary.opacity(farewellBurst ? 0.85 : 0.2))
                        .offset(farewellParticleOffset(index))
                        .opacity(farewellBurst ? 1 : 0)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [theme.bright.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(farewellBurst ? 1.15 : 0.7)

                Image(systemName: "sparkles")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(theme.gradient)
                    .scaleEffect(farewellBurst ? 1.08 : 0.85)
                    .symbolEffect(.bounce, value: farewellBurst)
            }
            .frame(height: 140)

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
            .scaleEffect(farewellBurst ? 1.0 : 0.94)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: farewellBurst)
        }
        .opacity(step == 4 && !contentVisible ? 0 : 1)
        .offset(y: step == 4 && !contentVisible ? 18 : 0)
    }

    // MARK: - Preview chrome

    private var miniBrowserPreview: some View {
        let chromeBG = previewIsDark ? Color(white: 0.12) : Color(white: 0.96)
        let barBG = previewIsDark ? Color(white: 0.18) : Color.white
        let pageBG = previewIsDark ? Color(white: 0.08) : Color(uiColor: .systemBackground)
        let muted = previewIsDark ? Color.white.opacity(0.45) : Color.black.opacity(0.35)

        return VStack(spacing: 0) {
            // Top status strip only; address bar stays at the bottom to match app defaults.
            HStack {
                Text("Zalla")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(muted)
                Spacer()
                Circle()
                    .fill(theme.primary.opacity(0.85))
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background(chromeBG)

            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.gradient.opacity(0.85))
                    .frame(height: 10)
                    .frame(maxWidth: 140)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(muted.opacity(0.45))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(muted.opacity(0.28))
                    .frame(height: 6)
                    .frame(maxWidth: 180)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(pageBG)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.primary)
                    Text("zalla.app")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(previewIsDark ? .white.opacity(0.85) : .primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(barBG, in: Capsule())
                .padding(.horizontal, 16)

                HStack {
                    ForEach(["chevron.backward", "chevron.forward", "square.on.square", "book", "ellipsis"], id: \.self) { name in
                        Image(systemName: name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(name == "ellipsis" ? theme.primary : muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
            }
            .background(chromeBG)
        }
        .background(chromeBG, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: theme.primary.opacity(0.18), radius: 18, y: 8)
        .animation(.easeInOut(duration: 0.28), value: appearance)
        .animation(.easeInOut(duration: 0.28), value: themeID)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live browser preview")
    }

    // MARK: - Shared pieces

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .shadow(color: theme.primary.opacity(0.06), radius: 12, y: 4)
    }

    private var appearanceBinding: Binding<String> {
        Binding(
            get: { appearance },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    appearance = newValue
                }
            }
        )
    }

    private let sparkleNames = ["sparkle", "star.fill", "seal.fill", "sparkles"]

    private func farewellParticleOffset(_ index: Int) -> CGSize {
        let angles: [CGFloat] = [-70, -35, 0, 40, 75, 110]
        let distances: [CGFloat] = farewellBurst ? [58, 70, 64, 72, 60, 68] : [8, 10, 6, 12, 8, 10]
        let angle = angles[index % angles.count] * .pi / 180
        let distance = distances[index % distances.count]
        return CGSize(width: cos(angle) * distance, height: sin(angle) * distance - 8)
    }

    private func stepHero(systemName: String) -> some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(theme.gradient.opacity(0.22))
                    .frame(width: 96, height: 96)
                    .blur(radius: 2)
                Circle()
                    .fill(theme.gradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: theme.primary.opacity(0.35), radius: 16, y: 8)
                Image(systemName: systemName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: step)
            }
            .scaleEffect(contentVisible ? 1 : 0.82)
            .opacity(contentVisible ? 1 : 0)
            Spacer()
        }
        .padding(.top, 4)
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

    private func goTo(_ newStep: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            step = newStep
        }
    }

    private func finish() {
        // Keep onboarding aligned with real defaults unless the user chose otherwise above.
        if toolbarStyleRaw.isEmpty {
            toolbarStyleRaw = ToolbarStyle.classic.rawValue
        }
        if addressBarPlacementRaw.isEmpty {
            addressBarPlacementRaw = AddressBarPlacement.bottom.rawValue
        }
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
                goTo(4)
            } catch {
                importMessage = error.localizedDescription
            }
        }
    }
}
