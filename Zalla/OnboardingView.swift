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

    static let privacyPolicyURL = URL(string: "https://zalla.gg/privacy/")!
    static let supportURL = URL(string: "https://zalla.gg/support/")!

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
                    quickSetupLook.tag(1)
                    quickSetupNavigation.tag(2)
                    bringYourStuff.tag(3)
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
                Link(destination: Self.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                        .font(.footnote.weight(.semibold))
                }
                .padding(.top, 4)
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

    private var quickSetupLook: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(
                title: "Quick Setup",
                subtitle: "Make Zalla yours. Everything here can be changed later in Settings."
            )
            .padding(.horizontal, 24)

            livePreview
                .padding(.horizontal, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance").font(.headline)
                        Picker("Appearance", selection: appearanceBinding) {
                            ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(20)
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Accent").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
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
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            if selected {
                                                Image(systemName: "checkmark")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.white)
                                                    .transition(.scale.combined(with: .opacity))
                                            }
                                        }
                                        .scaleEffect(selected ? 1.12 : 1.0)
                                        .shadow(color: selected ? swatch.primary.opacity(0.45) : .clear, radius: 10, y: 4)
                                        .accessibilityLabel(id.displayName)
                                        .accessibilityAddTraits(selected ? .isSelected : [])
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Search engine").font(.headline)
                            Spacer()
                            Picker("Search engine", selection: $searchEngine) {
                                ForEach(SearchEngine.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                            }
                            .pickerStyle(.menu)
                        }
                        Text("Searches open inside Zalla. Your chosen engine receives what you search for.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(cardBackground)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            nextButton("Continue") { goTo(2) }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
        .padding(.top, 12)
        .opacity(step == 1 && !contentVisible ? 0 : 1)
        .offset(y: step == 1 && !contentVisible ? 18 : 0)
    }

    private var quickSetupNavigation: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(
                title: "Navigation",
                subtitle: "Pick how your controls sit on screen. The preview updates as you choose."
            )
            .padding(.horizontal, 24)

            livePreview
                .padding(.horizontal, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Toolbar").font(.headline)
                        ForEach(ToolbarStyle.allCases) { style in
                            toolbarStyleOption(style)
                        }
                    }
                    .padding(20)
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Address bar").font(.headline)
                        Picker("Address bar", selection: placementBinding) {
                            ForEach(AddressBarPlacement.allCases) { placement in
                                Text(placement.rawValue).tag(placement.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(20)
                    .background(cardBackground)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            nextButton("Continue") { goTo(3) }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
        .padding(.top, 12)
        .opacity(step == 2 && !contentVisible ? 0 : 1)
        .offset(y: step == 2 && !contentVisible ? 18 : 0)
    }

    private func toolbarStyleOption(_ style: ToolbarStyle) -> some View {
        let selected = (ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic) == style
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                toolbarStyleRaw = style.rawValue
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: style.symbolName)
                    .font(.title3)
                    .foregroundStyle(selected ? .white : theme.primary)
                    .frame(width: 42, height: 42)
                    .background(
                        selected ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(theme.primary.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(style.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? theme.primary : Color.secondary.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? theme.primary.opacity(0.08) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? theme.primary.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var bringYourStuff: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHero(systemName: "tray.and.arrow.down.fill")
                header(
                    title: "Bring your stuff",
                    subtitle: "Passwords stay with Apple. Bookmarks come in from a file. Both are optional."
                )

                VStack(alignment: .leading, spacing: 12) {
                    Label("Passwords", systemImage: "key.fill")
                        .font(.headline)
                    Text("Zalla uses Apple Passwords and iCloud Keychain AutoFill. There is no separate Zalla vault. Turn on AutoFill so Safari and Zalla share the same saved passwords.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        openPasswordSettings()
                    } label: {
                        Text("Open password settings")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Bookmarks", systemImage: "bookmark.fill")
                        .font(.headline)
                    Text("Import an HTML bookmark file exported from Safari, Chrome, or Firefox. You can also do this later in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import HTML bookmarks", systemImage: "square.and.arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
                .background(cardBackground)

                nextButton("Continue") { goTo(4) }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
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
                if (ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic) == .quickAction {
                    Text("Tip: tap the center button for your controls, or the search icon to search.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 18) {
                    Link("Privacy Policy", destination: Self.privacyPolicyURL)
                    Link("Support", destination: Self.supportURL)
                }
                .font(.footnote.weight(.semibold))
                .padding(.top, 4)
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

    private var livePreview: some View {
        ChromeStylePreview(
            style: ToolbarStyle(rawValue: toolbarStyleRaw) ?? .classic,
            placement: AddressBarPlacement(rawValue: addressBarPlacementRaw) ?? .bottom,
            isDark: previewIsDark,
            theme: theme
        )
    }

    // MARK: - Shared pieces

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .shadow(color: theme.primary.opacity(0.06), radius: 12, y: 4)
    }

    private var placementBinding: Binding<String> {
        Binding(
            get: { addressBarPlacementRaw },
            set: { newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    addressBarPlacementRaw = newValue
                }
            }
        )
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
