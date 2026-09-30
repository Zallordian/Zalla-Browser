import SwiftUI

/// The small engine label in the search bar. Press and hold opens a scroll wheel to switch engines.
/// A plain tap does nothing extra.
struct SearchEngineChip: View {
    let theme: ZallaTheme
    @AppStorage(SearchEngine.storageKey) private var engineRaw = SearchEngine.defaultEngine.rawValue
    @State private var showWheel = false

    private var engine: SearchEngine {
        SearchEngine(rawValue: engineRaw) ?? SearchEngine.defaultEngine
    }

    var body: some View {
        Text(engine == .kagi ? "Kagi" : engine.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(theme.primary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.primary.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: 0.45) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showWheel = true
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Searching with \(engine.displayName)")
            .accessibilityHint("Press and hold to change the search engine")
            .accessibilityAction(named: "Change search engine") { showWheel = true }
            .sheet(isPresented: $showWheel) {
                SearchEngineWheelSheet()
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
            }
    }
}

/// iOS style scroll wheel for choosing the search engine.
struct SearchEngineWheelSheet: View {
    @AppStorage(SearchEngine.storageKey) private var engineRaw = SearchEngine.defaultEngine.rawValue
    @AppStorage(SearchEngine.customTemplateKey) private var customTemplate = ""
    @Environment(\.dismiss) private var dismiss

    private var choices: [SearchEngine] {
        SearchEngine.choices(
            customTemplate: customTemplate,
            selected: SearchEngine(rawValue: engineRaw)
        )
    }

    var body: some View {
        NavigationStack {
            Picker("Search engine", selection: $engineRaw) {
                ForEach(choices, id: \.rawValue) { engine in
                    Text(engine.displayName).tag(engine.rawValue)
                }
            }
            .pickerStyle(.wheel)
            .padding(.horizontal)
            .navigationTitle("Search engine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

/// Search engine rows for Settings: the menu plus the Custom URL address when it is chosen.
struct SearchEngineSettingsRows: View {
    @AppStorage(SearchEngine.storageKey) private var engineRaw = SearchEngine.defaultEngine.rawValue
    @AppStorage(SearchEngine.customTemplateKey) private var customTemplate = ""

    var body: some View {
        Picker("Search engine", selection: $engineRaw) {
            ForEach(SearchEngine.allCases, id: \.rawValue) { engine in
                Text(engine.displayName).tag(engine.rawValue)
            }
        }
        if engineRaw == SearchEngine.custom.rawValue {
            VStack(alignment: .leading, spacing: 6) {
                TextField("https://example.com/search?q=%s", text: $customTemplate)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Text(SearchEngine.customURLTemplate(from: customTemplate) == nil
                    ? "Enter a web address with %s where your search words go. Until then Zalla searches with Brave."
                    : "Your search words replace %s.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        if engineRaw == SearchEngine.kagi.rawValue {
            Text("Kagi is a paid search engine. You need a Kagi account to see results.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
