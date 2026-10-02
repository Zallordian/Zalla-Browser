import SwiftUI

/// Burn It All's full-screen effect: stylized flame tongues in lemon yellow, deep orange, and red rise over the browser
/// (which chars and darkens underneath), fill the screen, break apart into single licks, and fade into glowing embers
/// on black. Then a plain "Clearing browsing data..." label shows until Zalla closes. Drawn with one Canvas in a
/// TimelineView capped at 60 frames a second, no assets, no network. With Reduce Motion, or with the effect switched
/// off in Settings, it is a quick fade.
/// The timing and shapes live in BurnFire.swift. This view only draws. The wipe and the exit happen in BrowserStore
/// whether or not this ever appears.
struct BurnOverlay: View {
    let plan: BurnEffectPlan

    var body: some View {
        // The clock comes from the plan's start time, not from view state, so rebuilding this view
        // (for example when the tabs go away behind it) can never replay the fire.
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = BurnFire.progress(startedAt: plan.startedAt, now: timeline.date, duration: plan.duration)
            ZStack {
                switch plan.style {
                case .fire:
                    if t >= 1 {
                        Color.black.ignoresSafeArea()
                    } else {
                        FireScene(t: t, duration: plan.duration)
                    }
                    clearingLabel(light: true)
                        .opacity(BurnFire.labelOpacity(at: t))
                case .fade:
                    Color(uiColor: .systemBackground)
                        .opacity(0.96 * BurnFire.smooth(t))
                        .ignoresSafeArea()
                    clearingLabel(light: false)
                        .opacity(t >= 1 ? 1 : 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clearing browsing data. Zalla will close in a moment.")
    }

    private func clearingLabel(light: Bool) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(light ? Color.white : Color.secondary)
            Text("Clearing browsing data...")
                .font(.subheadline)
                .foregroundStyle(light ? Color.white.opacity(0.85) : Color.secondary)
        }
        .padding(32)
    }
}

/// One frame of the fire: char and heat behind, flame tongues, then embers.
private struct FireScene: View {
    let t: Double
    let duration: Double

    // Back row: deep red, burnt orange, orange. Front row: orange-red, orange, lemon yellow core.
    private static let backColors: [Color] = [
        Color(red: 0.56, green: 0.04, blue: 0.05),
        Color(red: 0.86, green: 0.17, blue: 0.05),
        Color(red: 1.0, green: 0.42, blue: 0.06)
    ]
    private static let frontColors: [Color] = [
        Color(red: 0.96, green: 0.26, blue: 0.04),
        Color(red: 1.0, green: 0.56, blue: 0.07),
        Color(red: 1.0, green: 0.93, blue: 0.36)
    ]
    private static let widthScales: [Double] = [1.0, 0.7, 0.42]
    private static let heightScales: [Double] = [1.0, 0.82, 0.58]

    var body: some View {
        let intensity = BurnFire.intensity(at: t)
        return ZStack {
            // The browser underneath chars and goes dark.
            Color.black.opacity(BurnFire.cover(at: t))
            // Heat rising from the bottom of the screen.
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.0, green: 0.38, blue: 0.05).opacity(0.7 * intensity), location: 0),
                    .init(color: Color(red: 0.7, green: 0.08, blue: 0.04).opacity(0.35 * intensity), location: 0.55),
                    .init(color: Color.clear, location: 1)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            Canvas { context, size in
                drawTongues(&context, size: size)
                drawEmbers(&context, size: size)
            }
        }
        .ignoresSafeArea()
    }

    private func drawTongues(_ context: inout GraphicsContext, size: CGSize) {
        let time = t * duration
        let width = Double(size.width)
        let height = Double(size.height)
        for tongue in BurnFire.tongues {
            let state = BurnFire.state(of: tongue, at: t)
            guard state.scale > 0.01, state.opacity > 0.01 else { continue }
            let outline = BurnFire.outline(of: tongue, time: time)
            let colors = tongue.row == 0 ? Self.backColors : Self.frontColors
            // The base sits just below the bottom edge and floats up as the tongue breaks loose.
            let baseX = tongue.baseX * width
            let baseY = height * (1.03 - state.lift)
            for layer in 0..<colors.count {
                let drawWidth = tongue.width * width * (0.55 + 0.45 * state.scale) * Self.widthScales[layer]
                let drawHeight = tongue.height * height * state.scale * Self.heightScales[layer]
                var path = Path()
                for (index, point) in outline.enumerated() {
                    let spot = CGPoint(x: baseX + point.x * drawWidth, y: baseY - point.y * drawHeight)
                    if index == 0 {
                        path.move(to: spot)
                    } else {
                        path.addLine(to: spot)
                    }
                }
                path.closeSubpath()
                context.fill(path, with: .color(colors[layer].opacity(state.opacity)))
            }
        }
    }

    private func drawEmbers(_ context: inout GraphicsContext, size: CGSize) {
        guard t > 0.6 else { return }
        let width = Double(size.width)
        let height = Double(size.height)
        for ember in BurnFire.embers {
            let state = BurnFire.state(of: ember, at: t)
            guard state.alpha > 0.01 else { continue }
            let color = Color(red: 1.0, green: 0.12 + 0.32 * ember.warmth, blue: 0.04)
            let x = state.x * width
            let y = state.y * height
            let r = ember.radius
            let glow = CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)
            context.fill(Path(ellipseIn: glow), with: .color(color.opacity(0.2 * state.alpha)))
            let core = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: core), with: .color(color.opacity(state.alpha)))
        }
    }
}
