import SwiftUI

/// Mini browser used by onboarding Quick Setup. Redraws for every
/// toolbar style and address placement combination so the choice is visible before it is made.
struct ChromeStylePreview: View {
    let style: ToolbarStyle
    let placement: AddressBarPlacement
    let isDark: Bool
    let theme: ZallaTheme

    private var layout: ChromePreviewLayout { .make(style: style, placement: placement) }
    private var chromeBG: Color { isDark ? Color(white: 0.12) : Color(white: 0.96) }
    private var barBG: Color { isDark ? Color(white: 0.20) : Color.white }
    private var pageBG: Color { isDark ? Color(white: 0.07) : Color.white }
    private var muted: Color { isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.35) }
    private var strong: Color { isDark ? Color.white.opacity(0.88) : Color.black.opacity(0.78) }

    var body: some View {
        VStack(spacing: 0) {
            statusStrip
            if layout.addressAtTop {
                chromeRow(isTop: true)
            }
            page
            if !layout.addressAtTop {
                chromeRow(isTop: false)
            } else if layout.showsNavRow && layout.navRowAtBottom {
                navRow
                    .padding(.vertical, 8)
                    .background(chromeBG)
            }
        }
        .frame(height: 210)
        .background(chromeBG)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: theme.primary.opacity(0.18), radius: 18, y: 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: style)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: placement)
        .animation(.easeInOut(duration: 0.28), value: isDark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview: \(style.rawValue) toolbar, address bar at the \(placement.rawValue.lowercased())")
    }

    // MARK: - Pieces

    private var statusStrip: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(muted)
            Spacer()
            Capsule()
                .fill(muted.opacity(0.6))
                .frame(width: 22, height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(chromeBG)
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(theme.gradient.opacity(0.85))
                .frame(width: 120, height: 10)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(muted.opacity(0.45))
                .frame(height: 6)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(muted.opacity(0.28))
                .frame(maxWidth: 170)
                .frame(height: 6)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(muted.opacity(0.2))
                .frame(maxWidth: 130)
                .frame(height: 6)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(pageBG)
    }

    @ViewBuilder
    private func chromeRow(isTop: Bool) -> some View {
        Group {
            if layout.showsQuickActionButton {
                quickActionRow
            } else if layout.showsFloatingRow {
                floatingRow
            } else {
                VStack(spacing: 6) {
                    addressCapsule
                    if !isTop && layout.showsNavRow {
                        navRow
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(chromeBG)
        .transition(.move(edge: isTop ? .top : .bottom).combined(with: .opacity))
    }

    private var addressCapsule: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8))
                .foregroundStyle(muted)
            Text("zalla.gg")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(strong)
            Spacer(minLength: 0)
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(barBG, in: Capsule())
    }

    private var navRow: some View {
        HStack {
            ForEach(["chevron.backward", "chevron.forward", "square.and.arrow.up", "square.on.square", "ellipsis.circle"], id: \.self) { name in
                Image(systemName: name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(name == "ellipsis.circle" ? theme.primary : muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var floatingRow: some View {
        HStack(spacing: 6) {
            miniCircle("chevron.backward")
            miniCircle("chevron.forward")
            HStack(spacing: 6) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(muted)
                Text("Zalla")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(strong)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(barBG, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            miniCircle("square.and.arrow.up")
            miniCircle("ellipsis")
        }
    }

    private var quickActionRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(muted)
                Text("zalla.gg")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(strong)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(barBG, in: Capsule())
            .frame(maxWidth: .infinity)

            ZStack {
                Circle()
                    .fill(theme.gradient)
                    .frame(width: 34, height: 34)
                    .shadow(color: theme.primary.opacity(0.4), radius: 6, y: 3)
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack {
                Spacer(minLength: 0)
                Text("3")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(muted)
                    .frame(width: 14, height: 15)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(muted, lineWidth: 1.2))
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(muted)
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func miniCircle(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(muted)
            .frame(width: 22, height: 22)
            .background(barBG, in: Circle())
            .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
    }
}
