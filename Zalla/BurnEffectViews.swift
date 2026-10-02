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

/// A plain red, green, blue triple so colors can be blended for the flame gradients.
private struct Shade {
    let r: Double
    let g: Double
    let b: Double

    func color(_ opacity: Double = 1) -> Color {
        Color(red: r, green: g, blue: b).opacity(opacity)
    }

    func mixed(toward other: Shade, _ amount: Double) -> Shade {
        Shade(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount)
    }
}

/// One frame of the fire: char and heat behind, flame tongues, then embers.
private struct FireScene: View {
    let t: Double
    let duration: Double

    // Back row: deep red, burnt orange, orange. Front row: orange-red, orange, lemon yellow core.
    private static let backColors: [Shade] = [
        Shade(r: 0.56, g: 0.04, b: 0.05),
        Shade(r: 0.86, g: 0.17, b: 0.05),
        Shade(r: 1.0, g: 0.42, b: 0.06)
    ]
    private static let frontColors: [Shade] = [
        Shade(r: 0.96, g: 0.26, b: 0.04),
        Shade(r: 1.0, g: 0.56, b: 0.07),
        Shade(r: 1.0, g: 0.93, b: 0.36)
    ]
    /// Every flame layer is hotter and lighter at its base and a deeper red at its tip.
    private static let hotShade = Shade(r: 1.0, g: 0.82, b: 0.28)
    private static let deepShade = Shade(r: 0.62, g: 0.07, b: 0.04)
    private static let lemon = Shade(r: 1.0, g: 0.93, b: 0.36)
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
            let shades = tongue.row == 0 ? Self.backColors : Self.frontColors
            // The base sits just below the bottom edge and floats up as the tongue breaks loose.
            let baseX = tongue.baseX * width
            let baseY = height * (1.03 - state.lift)
            for layer in 0..<shades.count {
                let drawWidth = tongue.width * width * (0.55 + 0.45 * state.scale) * Self.widthScales[layer]
                let drawHeight = tongue.height * height * state.scale * Self.heightScales[layer]
                let path = Self.flamePath(outline, baseX: baseX, baseY: baseY, width: drawWidth, height: drawHeight)
                let isLemonCore = tongue.row == 1 && layer == shades.count - 1
                if isLemonCore {
                    drawBloom(&context, x: baseX, y: baseY - drawHeight * 0.22, radius: drawWidth * 0.95, opacity: state.opacity)
                }
                // Hot and light at the base, the layer's own color through the middle, deeper at the tip.
                let base = shades[layer]
                let gradient = Gradient(stops: [
                    .init(color: base.mixed(toward: Self.hotShade, 0.35).color(state.opacity), location: 0),
                    .init(color: base.color(state.opacity), location: 0.5),
                    .init(color: base.mixed(toward: Self.deepShade, 0.3).color(state.opacity * 0.92), location: 1)
                ])
                context.fill(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: baseX, y: baseY),
                        endPoint: CGPoint(x: baseX, y: baseY - drawHeight)
                    )
                )
            }
        }
    }

    /// The flame outline as soft quadratic curves, with the base corners kept sharp.
    private static func flamePath(_ outline: [BurnFire.Point], baseX: Double, baseY: Double, width: Double, height: Double) -> Path {
        func spot(_ point: BurnFire.Point) -> CGPoint {
            CGPoint(x: baseX + point.x * width, y: baseY - point.y * height)
        }
        var path = Path()
        guard let first = outline.first else { return path }
        path.move(to: spot(first))
        for segment in BurnFire.smoothSegments(outline) {
            path.addQuadCurve(to: spot(segment.end), control: spot(segment.control))
        }
        path.closeSubpath()
        return path
    }

    /// A soft lemon glow behind the bright core. A radial gradient, so there is no blur pass to pay for.
    private func drawBloom(_ context: inout GraphicsContext, x: Double, y: Double, radius: Double, opacity: Double) {
        guard radius > 1 else { return }
        let center = CGPoint(x: x, y: y)
        let glow = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        var bloom = context
        bloom.blendMode = .plusLighter
        bloom.fill(
            glow,
            with: .radialGradient(
                Gradient(colors: [Self.lemon.color(0.3 * opacity), Self.lemon.color(0)]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private func drawEmbers(_ context: inout GraphicsContext, size: CGSize) {
        guard t > 0.6 else { return }
        let width = Double(size.width)
        let height = Double(size.height)
        for ember in BurnFire.embers {
            let state = BurnFire.state(of: ember, at: t)
            guard state.alpha > 0.01 else { continue }
            let shade = Shade(r: 1.0, g: 0.12 + 0.32 * ember.warmth, b: 0.04)
            let x = state.x * width
            let y = state.y * height
            let r = ember.radius
            switch ember.kind {
            case 1:
                // A spark: a short bright streak, tilted, with a soft halo.
                let dx = cos(ember.angle) * r * 2.4
                let dy = sin(ember.angle) * r * 2.4
                var streak = Path()
                streak.move(to: CGPoint(x: x - dx, y: y - dy))
                streak.addLine(to: CGPoint(x: x + dx, y: y + dy))
                context.stroke(
                    streak,
                    with: .color(shade.color(0.18 * state.alpha)),
                    style: StrokeStyle(lineWidth: r * 2.6, lineCap: .round)
                )
                context.stroke(
                    streak,
                    with: .color(shade.mixed(toward: Self.hotShade, 0.45).color(state.alpha)),
                    style: StrokeStyle(lineWidth: max(r * 0.8, 1), lineCap: .round)
                )
            case 2:
                // An ash flake: a small dim tile that tumbles as it floats up.
                let tumble = ember.angle + state.y * 9
                let side = r * 1.6
                let tile = Path(CGRect(x: -side, y: -side * 0.6, width: side * 2, height: side * 1.2))
                    .applying(CGAffineTransform(rotationAngle: tumble).concatenating(CGAffineTransform(translationX: x, y: y)))
                context.fill(tile, with: .color(shade.mixed(toward: Self.deepShade, 0.35).color(0.85 * state.alpha)))
            default:
                // A glowing dot: a radial halo around a hot core.
                let halo = CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)
                context.fill(
                    Path(ellipseIn: halo),
                    with: .radialGradient(
                        Gradient(colors: [shade.color(0.38 * state.alpha), shade.color(0)]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: r * 3
                    )
                )
                let core = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: core), with: .color(shade.mixed(toward: Self.hotShade, 0.25).color(state.alpha)))
            }
        }
    }
}
