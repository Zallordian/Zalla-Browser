import SwiftUI

/// Full-page stand-in for a load that failed. Sits over the page area, clear of the chrome.
struct FriendlyErrorView: View {
    let error: FriendlyError
    let theme: ZallaTheme
    var onRetry: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: error.kind.symbolName)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(theme.primary)
                    .padding(.top, 48)
                    .accessibilityHidden(true)
                Text(error.kind.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let host = error.host {
                    Text(host)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(error.kind.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                VStack(spacing: 10) {
                    if error.kind.offersRetry {
                        Button(action: onRetry) {
                            Text("Try again")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
