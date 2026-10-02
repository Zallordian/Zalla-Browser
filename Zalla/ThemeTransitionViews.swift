import SwiftUI

/// The full-screen transition that plays when a themed page is refreshed or a pack is applied.
/// Jungle slides layered, softly shaded leaves in from both sides and back out. Space launches a rocket up the screen
/// with a long tapering flame, smoke puffs, and a glow that washes over the page and lifts away. Each one is a single
/// Canvas in a TimelineView capped at 60 frames a second, with no assets and no timers. The view removes itself when
/// it is done. The timing and scenery live in ThemeTransitionPlan.swift.
struct ThemeTransitionOverlay: View {
    /// What to play, or nil for nothing. Read when `pulse` changes.
    let plan: ThemeTransitionPlan?
    /// Changes every time a transition should play.
    let pulse: Int

    @State private var visible = false
    @State private var playing: ThemeTransitionPlan?
    @State private var start = Date()
    @State private var run = 0

    var body: some View {
        ZStack {
            if visible, let playing {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let progress = TransitionCurve.clamp(timeline.date.timeIntervalSince(start) / playing.duration)
                    scene(playing, progress: progress)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: pulse) { _, _ in play() }
    }

    @ViewBuilder
    private func scene(_ playing: ThemeTransitionPlan, progress: Double) -> some View {
        switch playing.style {
        case .fade:
            // Reduce Motion: the screen tints and clears again, nothing moves.
            (playing.kind == .jungle ? Color(red: 0.07, green: 0.3, blue: 0.15) : Color(red: 0.1, green: 0.08, blue: 0.25))
                .opacity(TransitionCurve.fadeOpacity(progress))
        case .full:
            switch playing.kind {
            case .jungle: JungleCanvas(progress: progress)
            case .space: SpaceCanvas(progress: progress, duration: playing.duration)
            }
        }
    }

    private func play() {
        guard let plan else { return }
        run += 1
        let current = run
        playing = plan
        start = Date()
        visible = true
        let length = plan.duration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(length * 1_000_000_000) + 80_000_000)
            guard current == run else { return }
            visible = false
        }
    }
}

// MARK: - Jungle

private struct JungleCanvas: View {
    let progress: Double

    /// Leaf shades per layer, back to front: darkest first. Each layer has a dark and a light green.
    private static let shades: [(dark: Color, light: Color)] = [
        (Color(red: 0.03, green: 0.18, blue: 0.10), Color(red: 0.05, green: 0.25, blue: 0.13)),
        (Color(red: 0.07, green: 0.32, blue: 0.16), Color(red: 0.12, green: 0.42, blue: 0.20)),
        (Color(red: 0.15, green: 0.50, blue: 0.24), Color(red: 0.26, green: 0.64, blue: 0.30))
    ]

    var body: some View {
        Canvas { context, size in
            draw(&context, size: size)
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let width = Double(size.width)
        let height = Double(size.height)
        let count = JungleLeaves.layerCount
        let screen = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        // A solid green behind the leaves, so the screen is fully covered at the moment the sides meet.
        let front = TransitionCurve.curtain(progress, layer: count - 1, of: count)
        let backing = TransitionCurve.smooth((front - 0.5) / 0.5)
        if backing > 0.001 {
            context.fill(
                Path(screen),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.05, green: 0.24, blue: 0.12).opacity(backing),
                        Color(red: 0.02, green: 0.13, blue: 0.07).opacity(backing)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: height)
                )
            )
        }

        for layer in 0..<count {
            let cover = TransitionCurve.curtain(progress, layer: layer, of: count)
            guard cover > 0.001 else { continue }
            let layerWidth = width * 0.62
            let hidden = layerWidth * (1.15 + 0.1 * Double(layer))
            let slide = (1 - cover) * hidden
            // Parallax: the layers also drift a little at different rates while they slide.
            let drift = (1 - cover) * height * 0.025 * Double(layer - 1)
            for side in 0..<2 {
                drawSide(&context, layer: layer, mirrored: side == 1, size: size, layerWidth: layerWidth, slide: slide, drift: drift)
            }
        }
    }

    private func drawSide(_ context: inout GraphicsContext, layer: Int, mirrored: Bool, size: CGSize,
                          layerWidth: Double, slide: Double, drift: Double) {
        let width = Double(size.width)
        let height = Double(size.height)
        let direction = mirrored ? -1.0 : 1.0
        let leaves = JungleLeaves.leaves(layer: layer, mirrored: mirrored)
        let shades = Self.shades[layer]

        var outlineDark = Path()
        var outlineLight = Path()
        var highlights = Path()
        var veins = Path()
        for leaf in leaves {
            let rootX = mirrored ? width - leaf.rootX * layerWidth + slide : leaf.rootX * layerWidth - slide
            let root = CGPoint(x: rootX, y: leaf.rootY * height + drift)
            let angle = leaf.angle + JungleLeaves.sway(leaf, progress: progress, layer: layer)
            let pieces = Self.leafPaths(
                leaf: leaf, root: root, angle: angle, direction: direction,
                length: leaf.length * layerWidth, bulge: leaf.width * layerWidth
            )
            if leaf.tone < 0.5 {
                outlineDark.addPath(pieces.outline)
            } else {
                outlineLight.addPath(pieces.outline)
            }
            highlights.addPath(pieces.half)
            veins.addPath(pieces.vein)
        }

        // Soft shadow under the leaves, offset away from the screen edge.
        var shadowed = outlineDark
        shadowed.addPath(outlineLight)
        let shadow = shadowed.applying(CGAffineTransform(translationX: CGFloat(5 * direction), y: 4))
        context.fill(shadow, with: .color(Color.black.opacity(0.18 + 0.06 * Double(layer))))

        context.fill(outlineDark, with: .color(shades.dark))
        context.fill(outlineLight, with: .color(shades.light))
        // One half of each leaf catches the light.
        context.fill(highlights, with: .color(Color.white.opacity(0.10)))
        context.stroke(veins, with: .color(Color.white.opacity(0.16)), lineWidth: 1)

        // The branch the leaves grow from, hugging the screen edge.
        let branchX = mirrored ? width - 26 + slide : -slide
        context.fill(Path(CGRect(x: branchX, y: 0, width: 26, height: height)), with: .color(shades.dark))
    }

    /// One leaf as three paths: its outline, the half that catches the light, and its midrib. The leaf is a pointed
    /// shape with a bulge that differs from one side to the other and a midrib that bows, so no two look alike.
    private static func leafPaths(leaf: LeafSpec, root: CGPoint, angle: Double, direction: Double,
                                  length: Double, bulge: Double) -> (outline: Path, half: Path, vein: Path) {
        let dx = direction * cos(angle)
        let dy = sin(angle)
        let nx = -dy
        let ny = dx
        func point(_ along: Double, _ across: Double) -> CGPoint {
            CGPoint(
                x: Double(root.x) + dx * length * along + nx * across,
                y: Double(root.y) + dy * length * along + ny * across
            )
        }
        let tip = point(1, 0)
        let bow = leaf.curve * length * 0.2
        let upper = bulge * leaf.asymmetry
        let lower = bulge / leaf.asymmetry

        var outline = Path()
        outline.move(to: root)
        outline.addCurve(to: tip, control1: point(0.22, bow * 0.6 + upper * 1.25), control2: point(0.72, bow * 0.9 + upper * 0.95))
        outline.addCurve(to: root, control1: point(0.7, bow * 0.9 - lower * 0.95), control2: point(0.2, bow * 0.6 - lower * 1.25))
        outline.closeSubpath()

        // The lit half sits on the side that faces up the screen.
        let lit = direction > 0 ? -1.0 : 1.0
        var half = Path()
        half.move(to: root)
        half.addCurve(
            to: tip,
            control1: point(0.22, bow * 0.6 + lit * bulge * 1.2),
            control2: point(0.72, bow * 0.9 + lit * bulge * 0.9)
        )
        half.addQuadCurve(to: root, control: point(0.5, bow))
        half.closeSubpath()

        var vein = Path()
        vein.move(to: root)
        vein.addQuadCurve(to: tip, control: point(0.5, bow))
        return (outline, half, vein)
    }
}

// MARK: - Space

private struct SpaceCanvas: View {
    let progress: Double
    let duration: Double

    private static let rocketWidth = 40.0
    private static let rocketHeight = 118.0

    var body: some View {
        Canvas { context, size in
            draw(&context, size: size)
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let width = Double(size.width)
        let height = Double(size.height)
        let rocketHeight = Self.rocketHeight
        let thrust = SpaceFlight.thrust(progress)
        let noseStart = height + 30
        let noseEnd = -rocketHeight - 60
        let noseY = noseStart + (noseEnd - noseStart) * thrust
        let centerX = width / 2 + 1.5 * sin(progress * 11)
        let tailY = noseY + rocketHeight
        let time = progress * duration

        drawWash(&context, width: width, height: height, noseY: noseY, thrust: thrust)
        drawStreaks(&context, width: width, height: height, thrust: thrust)
        drawSmoke(&context, width: width, height: height, noseStart: noseStart, noseEnd: noseEnd)
        drawGlow(&context, centerX: centerX, tailY: tailY, thrust: thrust)
        drawFlame(&context, centerX: centerX, tailY: tailY, height: height, thrust: thrust, time: time)
        drawRocket(&context, centerX: centerX, noseY: noseY)
    }

    /// The exhaust: a warm wash below the ship that fills the screen as it climbs, then lifts away upward.
    private func drawWash(_ context: inout GraphicsContext, width: Double, height: Double, noseY: Double, thrust: Double) {
        let top = max(noseY - height * 0.25 * thrust - Self.rocketHeight * 0.2, -height * 0.4)
        let bottom = height * 1.25 - SpaceFlight.lift(progress) * height * 1.9
        let length = bottom - top
        guard length > 2 else { return }
        let rise = min(height * 0.15 / length, 0.3)
        let fall = min(height * 0.25 / length, 0.3)
        let gradient = Gradient(stops: [
            .init(color: Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0), location: 0),
            .init(color: Color(red: 1.0, green: 0.9, blue: 0.62).opacity(0.97), location: rise),
            .init(color: Color(red: 1.0, green: 0.66, blue: 0.22).opacity(0.96), location: 0.5),
            .init(color: Color(red: 0.9, green: 0.3, blue: 0.08).opacity(0.96), location: 1 - fall),
            .init(color: Color(red: 0.8, green: 0.2, blue: 0.08).opacity(0), location: 1)
        ])
        context.fill(
            Path(CGRect(x: 0, y: top, width: width, height: length)),
            with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom))
        )
    }

    /// Thin lines of passing air, so the climb reads as speed.
    private func drawStreaks(_ context: inout GraphicsContext, width: Double, height: Double, thrust: Double) {
        let visibility = sin(Double.pi * progress) * (0.3 + 0.7 * thrust)
        guard visibility > 0.02 else { return }
        var lines = Path()
        for streak in SpaceFlight.streaks {
            let travelled = (streak.y + thrust * streak.speed).truncatingRemainder(dividingBy: 1)
            let y = travelled * height * 1.2 - height * 0.1
            let x = streak.x * width
            lines.move(to: CGPoint(x: x, y: y))
            lines.addLine(to: CGPoint(x: x, y: y + streak.length * height * (0.6 + thrust)))
        }
        context.stroke(lines, with: .color(Color.white.opacity(0.22 * visibility)), lineWidth: 1.2)
    }

    /// Soft puffs left in the air where the ship has been. They swell, drift, and fade.
    private func drawSmoke(_ context: inout GraphicsContext, width: Double, height: Double, noseStart: Double, noseEnd: Double) {
        for puff in SpaceFlight.puffs {
            let age = (progress - puff.spawn) / SpaceFlight.puffLife
            guard age > 0, age < 1 else { continue }
            let launchedAt = noseStart + (noseEnd - noseStart) * SpaceFlight.thrust(puff.spawn)
            let x = width / 2 + puff.offsetX * width + puff.driftX * width * age
            let y = launchedAt + Self.rocketHeight + 12 + age * height * 0.06
            let radius = puff.radius * width * (0.6 + 2.2 * age)
            let alpha = 0.5 * pow(1 - age, 1.4) * min(age * 10, 1)
            let center = CGPoint(x: x, y: y)
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.98, green: 0.93, blue: 0.88).opacity(alpha),
                        Color(red: 0.85, green: 0.78, blue: 0.74).opacity(alpha * 0.5),
                        Color(red: 0.8, green: 0.74, blue: 0.7).opacity(0)
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }

    private func drawGlow(_ context: inout GraphicsContext, centerX: Double, tailY: Double, thrust: Double) {
        let radius = Self.rocketHeight * (1.0 + 0.5 * thrust)
        let center = CGPoint(x: centerX, y: tailY)
        context.fill(
            Path(ellipseIn: CGRect(x: centerX - radius, y: tailY - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.75, blue: 0.4).opacity(0.6),
                    Color(red: 1.0, green: 0.45, blue: 0.12).opacity(0.22),
                    Color(red: 1.0, green: 0.4, blue: 0.1).opacity(0)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    /// A long tapering flame in three layers: orange outside, yellow in the middle, white-hot at the core.
    private func drawFlame(_ context: inout GraphicsContext, centerX: Double, tailY: Double, height: Double,
                           thrust: Double, time: Double) {
        let flicker = 1 + 0.06 * sin(time * 38)
        let baseLength = height * (0.2 + 0.32 * thrust) * flicker
        let baseHalfWidth = Self.rocketWidth * 0.3
        let layers: [(length: Double, width: Double, top: Color, bottom: Color)] = [
            (1.0, 1.0, Color(red: 1.0, green: 0.46, blue: 0.1).opacity(0.95), Color(red: 1.0, green: 0.3, blue: 0.08).opacity(0)),
            (0.76, 0.66, Color(red: 1.0, green: 0.78, blue: 0.3).opacity(0.97), Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0)),
            (0.48, 0.36, Color(red: 1.0, green: 1.0, blue: 0.92), Color(red: 1.0, green: 0.9, blue: 0.6).opacity(0))
        ]
        for (index, layer) in layers.enumerated() {
            let length = baseLength * layer.length
            let half = baseHalfWidth * layer.width
            let wobble = sin(time * 31 + Double(index) * 1.7) * half * 0.35
            var path = Path()
            path.move(to: CGPoint(x: centerX - half, y: tailY - 4))
            path.addQuadCurve(
                to: CGPoint(x: centerX + wobble, y: tailY + length),
                control: CGPoint(x: centerX - half * 0.95, y: tailY + length * 0.42)
            )
            path.addQuadCurve(
                to: CGPoint(x: centerX + half, y: tailY - 4),
                control: CGPoint(x: centerX + half * 0.95 + wobble * 0.3, y: tailY + length * 0.42)
            )
            path.closeSubpath()
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [layer.top, layer.bottom]),
                    startPoint: CGPoint(x: centerX, y: tailY),
                    endPoint: CGPoint(x: centerX, y: tailY + length)
                )
            )
        }
    }

    /// A slim ship: warm white hull with soft shading, graphite fins and nozzle, a small round window.
    private func drawRocket(_ context: inout GraphicsContext, centerX: Double, noseY: Double) {
        let bodyHeight = Self.rocketHeight - 10
        let half = Self.rocketWidth / 2
        let bodyEnd = noseY + bodyHeight
        let graphite = Color(red: 0.2, green: 0.22, blue: 0.28)

        // Fins first, so the hull sits over their roots.
        for side in [-1.0, 1.0] {
            var fin = Path()
            fin.move(to: CGPoint(x: centerX + side * half * 0.9, y: bodyEnd - bodyHeight * 0.34))
            fin.addLine(to: CGPoint(x: centerX + side * (half + 15), y: bodyEnd + 8))
            fin.addLine(to: CGPoint(x: centerX + side * half * 0.9, y: bodyEnd - 2))
            fin.closeSubpath()
            context.fill(fin, with: .color(graphite))
        }

        // Nozzle.
        var nozzle = Path()
        nozzle.move(to: CGPoint(x: centerX - half * 0.55, y: bodyEnd - 2))
        nozzle.addLine(to: CGPoint(x: centerX + half * 0.55, y: bodyEnd - 2))
        nozzle.addLine(to: CGPoint(x: centerX + half * 0.75, y: bodyEnd + 10))
        nozzle.addLine(to: CGPoint(x: centerX - half * 0.75, y: bodyEnd + 10))
        nozzle.closeSubpath()
        context.fill(nozzle, with: .color(Color(red: 0.13, green: 0.14, blue: 0.18)))

        // Hull: a long pointed nose, then straight sides.
        var hull = Path()
        hull.move(to: CGPoint(x: centerX, y: noseY))
        hull.addQuadCurve(
            to: CGPoint(x: centerX + half, y: noseY + bodyHeight * 0.36),
            control: CGPoint(x: centerX + half * 0.95, y: noseY + bodyHeight * 0.08)
        )
        hull.addLine(to: CGPoint(x: centerX + half, y: bodyEnd))
        hull.addLine(to: CGPoint(x: centerX - half, y: bodyEnd))
        hull.addLine(to: CGPoint(x: centerX - half, y: noseY + bodyHeight * 0.36))
        hull.addQuadCurve(
            to: CGPoint(x: centerX, y: noseY),
            control: CGPoint(x: centerX - half * 0.95, y: noseY + bodyHeight * 0.08)
        )
        hull.closeSubpath()
        context.fill(
            hull,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 1.0, green: 0.98, blue: 0.95), location: 0),
                    .init(color: Color(red: 0.9, green: 0.9, blue: 0.93), location: 0.5),
                    .init(color: Color(red: 0.58, green: 0.61, blue: 0.69), location: 1)
                ]),
                startPoint: CGPoint(x: centerX - half, y: noseY),
                endPoint: CGPoint(x: centerX + half, y: noseY)
            )
        )

        // A thin band, then the window.
        context.fill(
            Path(CGRect(x: centerX - half, y: noseY + bodyHeight * 0.68, width: Self.rocketWidth, height: 4)),
            with: .color(graphite.opacity(0.55))
        )
        let windowRadius = half * 0.36
        let windowCenter = CGPoint(x: centerX, y: noseY + bodyHeight * 0.42)
        let windowRect = CGRect(
            x: windowCenter.x - windowRadius, y: windowCenter.y - windowRadius,
            width: windowRadius * 2, height: windowRadius * 2
        )
        context.fill(Path(ellipseIn: windowRect.insetBy(dx: -2, dy: -2)), with: .color(graphite))
        context.fill(
            Path(ellipseIn: windowRect),
            with: .radialGradient(
                Gradient(colors: [Color(red: 0.62, green: 0.82, blue: 0.97), Color(red: 0.14, green: 0.28, blue: 0.52)]),
                center: CGPoint(x: windowCenter.x - windowRadius * 0.3, y: windowCenter.y - windowRadius * 0.3),
                startRadius: 0,
                endRadius: windowRadius * 1.4
            )
        )
    }
}
