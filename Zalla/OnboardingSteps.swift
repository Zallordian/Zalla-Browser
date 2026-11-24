import StoreKit
import SwiftUI

/// Redesign phase 3: the six setup screens, in order. TabView tags use the raw values.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case look
    case search
    case bringStuff
    case unlock
    case farewell

    /// Read out for the page dots, like "Page 3 of 6".
    var pageLabel: String { "Page \(rawValue + 1) of \(OnboardingStep.allCases.count)" }
}

/// Build 53: shared spacing for the bottom of every setup screen. The screen's main button sits
/// `buttonBottomPadding` above the dots row, and the dots get their own row under it.
enum OnboardingMetrics {
    static let buttonBottomPadding: CGFloat = 14
    static let dotsTopSpacing: CGFloat = 4
    static let dotsBottomSpacing: CGFloat = 10
    static let dotSize: CGFloat = 7
    static let activeDotWidth: CGFloat = 20
    /// How far the list fades out at its top and bottom edges instead of being cut off.
    static let scrollFade: CGFloat = 22
}

/// Build 53: the page dots, on a row of their own under each screen's button.
struct OnboardingPageDots: View {
    let current: Int
    let theme: ZallaTheme

    var body: some View {
        HStack(spacing: 7) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                let active = step.rawValue == current
                Capsule()
                    .fill(active ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(Color.primary.opacity(0.22)))
                    .frame(width: active ? OnboardingMetrics.activeDotWidth : OnboardingMetrics.dotSize,
                           height: OnboardingMetrics.dotSize)
            }
        }
        .frame(height: OnboardingMetrics.dotSize + 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(OnboardingStep(rawValue: current)?.pageLabel ?? "")
    }
}

/// Build 53: scrolling lists fade out under the header and above the button instead of cutting text off.
struct OnboardingScrollFade: ViewModifier {
    func body(content: Content) -> some View {
        content.mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: OnboardingMetrics.scrollFade)
                Rectangle().fill(.black)
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: OnboardingMetrics.scrollFade)
            }
        )
    }
}

extension View {
    func onboardingScrollFade() -> some View { modifier(OnboardingScrollFade()) }
}

/// The rounded card every setup screen uses.
struct OnboardingCard: ViewModifier {
    let theme: ZallaTheme

    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: theme.primary.opacity(0.06), radius: 12, y: 4)
            )
    }
}

extension View {
    func onboardingCard(_ theme: ZallaTheme) -> some View { modifier(OnboardingCard(theme: theme)) }
}

extension SearchEnginePrivacy.Level {
    var color: Color {
        switch self {
        case .collectsALot: return .red
        case .collectsSome: return .yellow
        case .collectsLittle: return .green
        }
    }
}

/// The red, yellow, or green bar, as three short segments. More filled and greener means the engine collects less.
/// Fixed widths so the bar and its label line up on every card.
struct PrivacyMeter: View {
    let level: SearchEnginePrivacy.Level

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(SearchEnginePrivacy.Level.allCases, id: \.rawValue) { segment in
                    Capsule()
                        .fill(segment.rawValue <= level.rawValue ? level.color : Color.primary.opacity(0.12))
                        .frame(width: 16, height: 6)
                }
            }
            Text(level.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(level == .collectsSome ? Color.primary.opacity(0.7) : level.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Privacy: \(level.label)")
    }
}

// MARK: - Screen 3: search and privacy

struct OnboardingSearchStep: View {
    let theme: ZallaTheme
    @Binding var selection: String
    let onContinue: () -> Void

    private var engines: [SearchEngine] {
        SearchEnginePrivacy.setupOrder(SearchEngine.choices(customTemplate: nil).filter { $0 != .custom })
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(SearchEnginePrivacy.Copy.title)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(SearchEnginePrivacy.Copy.enginesNote)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    promise

                    VStack(spacing: 8) {
                        ForEach(engines, id: \.rawValue) { engine in
                            row(engine)
                        }
                    }

                    Text(SearchEnginePrivacy.Copy.footer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .onboardingScrollFade()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
    }

    private var promise: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(theme.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(SearchEnginePrivacy.Copy.zallaPromiseTitle)
                    .font(.subheadline.weight(.semibold))
                Text(SearchEnginePrivacy.Copy.zallaPromise)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.primary.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }

    private func row(_ engine: SearchEngine) -> some View {
        let selected = selection == engine.rawValue
        let rating = SearchEnginePrivacy.rating(for: engine)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selection = engine.rawValue }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // A letter badge instead of a logo: works offline and uses no company artwork.
                Text(String(engine.rawValue.prefix(1)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? Color.white : theme.primary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(selected ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(theme.primary.opacity(0.12)))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(engine.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if engine == SearchEngine.defaultEngine { chip("Default") }
                        if engine == .kagi { chip("Paid") }
                    }
                    if let rating {
                        PrivacyMeter(level: rating.level)
                        Text(selected ? rating.reason : rating.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if selected {
                            Link("Read the privacy policy", destination: rating.policyURL)
                                .font(.caption.weight(.semibold))
                                .padding(.top, 1)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? theme.primary : Color.secondary.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? theme.primary.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? theme.primary.opacity(0.6) : Color.primary.opacity(0.05), lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.primary.opacity(0.14), in: Capsule())
            .foregroundStyle(theme.primary)
    }
}

// MARK: - Screen 5: Zalla Unlock

struct OnboardingUnlockStep: View {
    let theme: ZallaTheme
    /// Moves to the last screen. Called by Not right now, Continue, and shortly after a purchase goes through.
    let onContinue: () -> Void
    @ObservedObject private var unlock = ZallaUnlock.shared
    @State private var unlockItems = ZallaUnlockBenefits.unlockItems()
    @State private var freeItems = ZallaUnlockBenefits.freeItems()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ZallaUnlockBenefits.Copy.title)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(ZallaUnlockBenefits.Copy.subtitle)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(ZallaUnlockBenefits.Copy.unlockHeader).font(.headline)
                        ForEach(unlockItems) { item in
                            itemRow(item, highlighted: true)
                        }
                    }
                    .onboardingCard(theme)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(ZallaUnlockBenefits.Copy.freeHeader).font(.headline)
                        ForEach(freeItems) { item in
                            itemRow(item, highlighted: false)
                        }
                    }
                    .onboardingCard(theme)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .onboardingScrollFade()

            actions
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
        .task { await unlock.loadProduct() }
        .onChange(of: unlock.isUnlocked) { _, unlocked in
            guard unlocked else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onContinue() }
        }
    }

    private func itemRow(_ item: ZallaUnlockBenefits.Item, highlighted: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(highlighted ? .white : theme.primary)
                .frame(width: 32, height: 32)
                .background(
                    highlighted ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(theme.primary.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.semibold))
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            if unlock.isUnlocked {
                Label(ZallaUnlockBenefits.Copy.unlocked, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primary)
                primaryButton("Continue", action: onContinue)
            } else {
                buyButton
                statusText
                HStack(spacing: 10) {
                    Button {
                        Task { await unlock.restore() }
                    } label: {
                        Text(ZallaUnlockBenefits.Copy.restore)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(unlock.isBusy)

                    Button(action: onContinue) {
                        Text(ZallaUnlockBenefits.Copy.notNow)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                Text(ZallaUnlockBenefits.Copy.smallPrint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var buyButton: some View {
        if let product = unlock.product {
            Button {
                Task { await unlock.purchase() }
            } label: {
                HStack(spacing: 8) {
                    if unlock.purchaseState == .purchasing { ProgressView().tint(.white) }
                    // The price is StoreKit's own localized string, never a typed-in number.
                    Text(ZallaUnlockBenefits.Copy.buyTitle(price: product.displayPrice))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .disabled(unlock.isBusy)
        } else if unlock.loadState == .unavailable {
            VStack(spacing: 6) {
                Text(ZallaUnlockProduct.unavailableMessage(loadFailed: unlock.loadFailed))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if unlock.loadFailed {
                    Button(ZallaUnlockProduct.Copy.tryAgain) { Task { await unlock.loadProduct() } }
                        .font(.footnote.weight(.semibold))
                }
            }
        } else {
            HStack(spacing: 8) {
                ProgressView()
                Text("Checking the App Store")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch unlock.purchaseState {
        case .pending:
            Text(ZallaUnlockProduct.Copy.pending).font(.footnote).foregroundStyle(.secondary)
        case .failed(let message), .message(let message):
            Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        default:
            EmptyView()
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
    }
}
