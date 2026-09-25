import SwiftUI

/// Mini browser used by onboarding Quick Setup. Redraws for every
/// toolbar style and address placement combination so the choice is visible before it is made.
/// Like the real browser, the page runs edge to edge and the chrome floats over a soft shade.
struct ChromeStylePreview: View {
    let style: ToolbarStyle
    let placement: AddressBarPlacement
    let isDark: Bool
    let theme: ZallaTheme
    /// Toolbar buttons to draw. Defaults to the built-in layout, as onboarding shows it.
    var toolbarItems: ToolbarLayout = .default

    private var layout: ChromePreviewLayout { .make(style: style, placement: placement) }
    private var barBG: Color { isDark ? Color(white: 0.20) : Color.white }
    private var pageBG: Color { isDark ? Color(white: 0.07) : Color.white }
    private var muted: Color { isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.35) }
    private var strong: Color { isDark ? Color.white.opacity(0.88) : Color.black.opacity(0.78) }

    var body: some View {
        ZStack {
            page
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    statusStrip
                    if layout.addressAtTop {
                        chromeRow(isTop: true)
                    }
                }
                .background(scrim(isTop: true, strong: layout.addressAtTop))
                Spacer(minLength: 0)
                if !layout.addressAtTop {
                    chromeRow(isTop: false)
                        .background(scrim(isTop: false))
                } else if layout.showsNavRow && layout.navRowAtBottom {
                    navRow
                        .padding(.vertical, 8)
                        .background(scrim(isTop: false))
                }
            }
        }
        .frame(height: 210)
        .background(pageBG)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: theme.primary.opacity(0.18), radius: 18, y: 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: style)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: placement)
        .animation(.easeInOut(duration: 0.28), value: isDark)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toolbarItems)
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
    }

    /// Soft shade that deepens toward the screen edge, matching the browser's translucent chrome.
    private func scrim(isTop: Bool, strong: Bool = true) -> some View {
        let shade: Color = isDark ? .black : .white
        let edgeOpacity = strong ? (isDark ? 0.58 : 0.72) : (isDark ? 0.35 : 0.45)
        return LinearGradient(
            colors: [shade.opacity(0), shade.opacity(edgeOpacity)],
            startPoint: isTop ? .bottom : .top,
            endPoint: isTop ? .top : .bottom
        )
        .padding(isTop ? .bottom : .top, -14)
        .allowsHitTesting(false)
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
            // Hero block runs under the bottom chrome so the see-through shade is visible.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.primary.opacity(0.38), theme.primary.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.top, layout.addressAtTop ? 76 : 32)
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
            ForEach(toolbarItems.classic) { kind in
                Image(systemName: previewSymbol(kind, classic: true))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(kind == .menu ? theme.primary : muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Symbols as the onboarding preview has always drawn them.
    private func previewSymbol(_ kind: ToolbarItemKind, classic: Bool) -> String {
        switch kind {
        case .back: return "chevron.backward"
        case .forward: return "chevron.forward"
        case .menu: return classic ? "ellipsis.circle" : "ellipsis"
        default: return kind.symbolName
        }
    }

    private var floatingRow: some View {
        HStack(spacing: 6) {
            ForEach(toolbarItems.compactLeading) { kind in
                miniCircle(previewSymbol(kind, classic: false))
            }
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
            ForEach(toolbarItems.compactTrailing) { kind in
                miniCircle(previewSymbol(kind, classic: false))
            }
        }
    }

    private var quickActionRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.primary)
                Image(systemName: "lock.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(muted)
                Text("zalla.gg")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(strong)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(theme.primary.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(theme.primary, lineWidth: 1.2))
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

            HStack(spacing: 4) {
                Spacer(minLength: 0)
                ForEach(toolbarItems.quickActionBar) { kind in
                    quickActionSlot(kind)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func quickActionSlot(_ kind: ToolbarItemKind) -> some View {
        if kind == .tabs {
            miniSquare {
                Text("3")
                    .font(.system(size: 9, weight: .bold))
            }
        } else {
            Image(systemName: previewSymbol(kind, classic: false))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 26, height: 26)
                .background(barBG.opacity(0.55), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    /// Accent-outlined square for the Quick Action tabs button (stroke matches the search pill).
    private func miniSquare<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundStyle(theme.primary)
            .frame(width: 14, height: 15)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.primary, lineWidth: 1.2))
            .frame(width: 26, height: 26)
            .background(barBG.opacity(0.55), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
