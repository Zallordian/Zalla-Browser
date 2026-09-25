import SwiftUI
import StoreKit
import UIKit

/// Settings row that opens the tip jar, with a small Supporter badge after a tip.
struct SupportZallaRow: View {
    let theme: ZallaTheme
    @AppStorage(SupporterState.supporterKey) private var isSupporter = false

    var body: some View {
        HStack {
            Label {
                Text("Support Zalla")
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(theme.primary)
            }
            Spacer(minLength: 8)
            if isSupporter {
                SupporterBadge(theme: theme)
            }
        }
    }
}

struct SupporterBadge: View {
    let theme: ZallaTheme

    var body: some View {
        Label("Supporter", systemImage: "heart.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.primary.opacity(0.12), in: Capsule())
            .accessibilityLabel("Supporter")
    }
}

/// Tip jar with three consumable tips. Prices always come from StoreKit.
struct SupportZallaView: View {
    let theme: ZallaTheme
    @StateObject private var store = TipStore()
    @AppStorage(SupporterState.supporterKey) private var isSupporter = false
    @AppStorage(SupporterState.tipCountKey) private var tipCount = 0

    var body: some View {
        List {
            Section {
                SupportHeader(theme: theme, isSupporter: isSupporter, tipCount: tipCount)
            }
            Section {
                tipContent
            } footer: {
                statusFooter
            }
        }
        .navigationTitle("Support Zalla")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
        .task { await store.loadProducts() }
        .sheet(isPresented: thanksBinding) {
            TipThanksView(theme: theme) { store.purchaseState = .idle }
                .presentationDetents([.medium])
        }
    }

    private var thanksBinding: Binding<Bool> {
        Binding(
            get: { store.purchaseState == .thanked },
            set: { if !$0 { store.purchaseState = .idle } }
        )
    }

    @ViewBuilder
    private var tipContent: some View {
        switch store.loadState {
        case .idle, .loading:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        case .unavailable:
            Text(TipJar.Copy.unavailable)
                .foregroundStyle(.secondary)
        case .loaded:
            ForEach(store.products, id: \.id) { product in
                TipButton(
                    product: product,
                    theme: theme,
                    isBusy: store.purchaseState == .purchasing(product.id),
                    isDisabled: store.isPurchasing
                ) {
                    Task { await store.purchase(product) }
                }
            }
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch store.purchaseState {
        case .pending:
            Text(TipJar.Copy.pending)
        case .failed:
            Text(TipJar.Copy.failed)
        default:
            Text("Payments are handled by Apple. Zalla never sees your payment details.")
        }
    }
}

private struct SupportHeader: View {
    let theme: ZallaTheme
    let isSupporter: Bool
    let tipCount: Int

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(theme.gradient)
                .accessibilityHidden(true)
            Text(TipJar.Copy.note)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if isSupporter {
                SupporterBadge(theme: theme)
                Text(tipCount == 1 ? "You have tipped once. Thank you!" : "You have tipped \(tipCount) times. Thank you!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct TipButton: View {
    let product: Product
    let theme: ZallaTheme
    let isBusy: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .foregroundStyle(.primary)
                    if !product.description.isEmpty {
                        Text(product.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                priceLabel
            }
            .padding(.vertical, 4)
        }
        .disabled(isDisabled)
        .accessibilityLabel("\(product.displayName), \(product.displayPrice)")
    }

    @ViewBuilder
    private var priceLabel: some View {
        if isBusy {
            ProgressView()
        } else {
            Text(product.displayPrice)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(theme.gradient, in: Capsule())
        }
    }
}

/// Shown after a successful tip.
private struct TipThanksView: View {
    let theme: ZallaTheme
    let onDone: () -> Void
    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.gradient)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
                .symbolEffect(.bounce, value: appeared)
                .accessibilityHidden(true)
            Text(TipJar.Copy.thanksTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(TipJar.Copy.thanksMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                onDone()
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .padding(28)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}
