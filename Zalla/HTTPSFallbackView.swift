import SwiftUI

/// Shown in place of the page when HTTPS-Only Mode could not open a site over a secure connection.
struct HTTPSFallbackView: View {
    let host: String
    let theme: ZallaTheme
    let onGoBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                card
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.slash.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(theme.gradient)
                .accessibilityHidden(true)
            Text(HTTPSOnly.noticeTitle)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(HTTPSOnly.noticeMessage(host: host))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                Button(action: onGoBack) {
                    Text(HTTPSOnly.goBackTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                Button(action: onContinue) {
                    Text(HTTPSOnly.continueTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .tint(theme.primary)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
