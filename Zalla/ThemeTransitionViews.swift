import SwiftUI

/// Where a theme transition is in its two halves: off screen, covering the page, then gone again.
private enum TransitionPhase {
    case start, middle, end
}

/// The full-screen transition that plays when a themed page is refreshed or a pack is applied.
/// Jungle slides a leaf curtain in from both sides and back out. Space sends a rocket up the screen
/// with its exhaust washing over the page. Everything is a static vector shape moved by a couple of
/// animations, so there are no timers and no video. The view removes itself when it is done.
struct ThemeTransitionOverlay: View {
    /// What to play, or nil for nothing. Read when `pulse` changes.
    let plan: ThemeTransitionPlan?
    /// Changes every time a transition should play.
    let pulse: Int

    @State private var phase: TransitionPhase = .start
    @State private var visible = false
    @State private var playing: ThemeTransitionPlan?
    @State private var run = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if visible, let playing {
                    switch playing.style {
                    case .fade:
                        fade(playing)
                    case .full:
                        switch playing.kind {
                        case .jungle: JungleCurtain(size: geo.size, phase: phase, leg: playing.duration / 2)
                        case .space: SpaceLaunch(size: geo.size, phase: phase, leg: playing.duration / 2)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: pulse) { _, _ in play() }
    }

    /// Reduce Motion: the screen tints and clears again, nothing moves.
    private func fade(_ playing: ThemeTransitionPlan) -> some View {
        let leg = playing.duration / 2
        return (playing.kind == .jungle ? Color(red: 0.07, green: 0.3, blue: 0.15) : Color(red: 0.1, green: 0.08, blue: 0.25))
            .opacity(phase == .middle ? 0.85 : 0)
            .animation(.easeInOut(duration: leg), value: phase)
    }

    private func play() {
        guard let plan else { return }
        run += 1
        let current = run
        playing = plan
        phase = .start
        visible = true
        let leg = plan.duration / 2
        Task { @MainActor in
            // Let the shapes appear at their start position first, then run the two halves.
            try? await Task.sleep(nanoseconds: 60_000_000)
            guard current == run else { return }
            phase = .middle
            try? await Task.sleep(nanoseconds: UInt64(leg * 1_000_000_000))
            guard current == run else { return }
            phase = .end
            try? await Task.sleep(nanoseconds: UInt64(leg * 1_000_000_000) + 50_000_000)
            guard current == run else { return }
            visible = false
            phase = .start
        }
    }
}

// MARK: - Jungle

private struct JungleCurtain: View {
    let size: CGSize
    let phase: TransitionPhase
    let leg: Double

    /// Leaf shades per layer: back is darkest, front is brightest.
    private static let shades: [(Color, Color)] = [
        (Color(red: 0.04, green: 0.22, blue: 0.11), Color(red: 0.06, green: 0.28, blue: 0.14)),
        (Color(red: 0.09, green: 0.38, blue: 0.18), Color(red: 0.14, green: 0.47, blue: 0.22)),
        (Color(red: 0.19, green: 0.58, blue: 0.27), Color(red: 0.29, green: 0.69, blue: 0.31))
    ]

    var body: some View {
        ZStack {
            // A solid green behind the leaves, so the screen is fully covered at the moment the sides meet.
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.24, blue: 0.12), Color(red: 0.03, green: 0.15, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(phase == .middle ? 1 : 0)
            .animation(backingAnimation, value: phase)

            ForEach(0..<JungleLeaves.layerCount, id: \.self) { layer in
                layerView(layer)
            }
        }
    }

    private var backingAnimation: Animation {
        phase == .middle
            ? .easeIn(duration: leg * 0.5).delay(leg * 0.5)
            : .easeOut(duration: leg * 0.5)
    }

    /// Back layers move first going in and last going out, which gives the curtain its depth.
    private func curtainAnimation(for layer: Int) -> Animation {
        let step = Double(layer)
        switch phase {
        case .middle: return .easeOut(duration: leg * 0.8).delay(leg * 0.1 * step)
        case .end: return .easeIn(duration: leg * 0.8).delay(leg * 0.1 * Double(JungleLeaves.layerCount - 1 - layer))
        case .start: return .linear(duration: 0)
        }
    }

    private func layerView(_ layer: Int) -> some View {
        let layerWidth = size.width * 0.62
        let hidden = layerWidth * (1.1 + 0.1 * Double(layer))
        let offset: CGFloat = phase == .middle ? 0 : hidden
        let shades = Self.shades[layer]
        return ZStack {
            JungleSide(leaves: JungleLeaves.leaves(layer: layer, mirrored: false), mirrored: false, shades: shades)
                .frame(width: layerWidth, height: size.height)
                .offset(x: -offset)
                .frame(maxWidth: .infinity, alignment: .leading)
            JungleSide(leaves: JungleLeaves.leaves(layer: layer, mirrored: true), mirrored: true, shades: shades)
                .frame(width: layerWidth, height: size.height)
                .offset(x: offset)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .animation(curtainAnimation(for: layer), value: phase)
    }
}

/// One side of one layer: leaves fanning in from the screen edge, with a soft shadow.
private struct JungleSide: View {
    let leaves: [LeafSpec]
    let mirrored: Bool
    let shades: (Color, Color)

    var body: some View {
        ZStack {
            LeafLayerShape(leaves: leaves, mirrored: mirrored, parity: 0).fill(shades.0)
            LeafLayerShape(leaves: leaves, mirrored: mirrored, parity: 1).fill(shades.1)
            LeafVeinShape(leaves: leaves, mirrored: mirrored)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
            // The branch the leaves grow from, hugging the screen edge.
            Rectangle()
                .fill(shades.0)
                .frame(width: 26)
                .frame(maxWidth: .infinity, alignment: mirrored ? .trailing : .leading)
        }
        .drawingGroup()
        .shadow(color: .black.opacity(0.35), radius: 8, x: mirrored ? -4 : 4, y: 2)
    }
}

/// Every leaf of a layer as one pointed oval path. Even and odd leaves are drawn separately so they get two shades.
private struct LeafLayerShape: Shape {
    let leaves: [LeafSpec]
    let mirrored: Bool
    let parity: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, leaf) in leaves.enumerated() where index % 2 == parity {
            let root = CGPoint(x: leaf.rootX * rect.width, y: leaf.rootY * rect.height)
            let length = leaf.length * rect.width
            let bulge = leaf.width * rect.width
            let tip = CGPoint(x: root.x + length * cos(leaf.angle), y: root.y + length * sin(leaf.angle))
            let normal = CGPoint(x: -sin(leaf.angle), y: cos(leaf.angle))
            let middle = CGPoint(x: root.x + (tip.x - root.x) * 0.45, y: root.y + (tip.y - root.y) * 0.45)
            path.move(to: root)
            path.addQuadCurve(to: tip, control: CGPoint(x: middle.x + normal.x * bulge, y: middle.y + normal.y * bulge))
            path.addQuadCurve(to: root, control: CGPoint(x: middle.x - normal.x * bulge, y: middle.y - normal.y * bulge))
            path.closeSubpath()
        }
        return mirrored ? path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.width, ty: 0)) : path
    }
}

/// A thin center line down each leaf.
private struct LeafVeinShape: Shape {
    let leaves: [LeafSpec]
    let mirrored: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for leaf in leaves {
            let root = CGPoint(x: leaf.rootX * rect.width, y: leaf.rootY * rect.height)
            let length = leaf.length * rect.width * 0.9
            path.move(to: root)
            path.addLine(to: CGPoint(x: root.x + length * cos(leaf.angle), y: root.y + length * sin(leaf.angle)))
        }
        return mirrored ? path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.width, ty: 0)) : path
    }
}

// MARK: - Space

private struct SpaceLaunch: View {
    let size: CGSize
    let phase: TransitionPhase
    let leg: Double

    private static let rocketWidth: CGFloat = 56
    private static let rocketHeight: CGFloat = 112

    var body: some View {
        let trailHeight = size.height * 0.5
        let groupHeight = Self.rocketHeight + trailHeight
        let startY = size.height / 2 + groupHeight / 2
        let endY = -size.height / 2 - groupHeight / 2
        // Halfway up the whole climb, so the speed is the same before and after the glow peaks.
        let middleY = (startY + endY) / 2
        let glowHeight = size.height * 1.3
        return ZStack {
            // The exhaust: a warm wash that rises with the ship, fills the screen, then lifts away upward.
            Rectangle()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.0, green: 0.45, blue: 0.1).opacity(0), location: 0),
                        .init(color: Color(red: 1.0, green: 0.4, blue: 0.1).opacity(0.9), location: 0.12),
                        .init(color: Color(red: 1.0, green: 0.7, blue: 0.25).opacity(0.95), location: 0.5),
                        .init(color: Color(red: 1.0, green: 0.93, blue: 0.7).opacity(0.98), location: 0.8),
                        .init(color: Color(red: 1.0, green: 0.55, blue: 0.2), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size.width, height: glowHeight)
                .offset(y: phase == .start ? glowHeight * 0.93 : (phase == .middle ? 0 : -glowHeight * 0.93))
                .opacity(phase == .middle ? 1 : 0)
                .animation(phase == .middle ? .easeOut(duration: leg) : .easeIn(duration: leg), value: phase)

            VStack(spacing: -8) {
                RocketBody()
                    .frame(width: Self.rocketWidth, height: Self.rocketHeight)
                RocketTrail()
                    .frame(width: Self.rocketWidth * 0.62, height: trailHeight)
            }
            .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.2).opacity(0.7), radius: 14)
            .offset(y: phase == .start ? startY : (phase == .middle ? middleY : endY))
            .animation(.linear(duration: phase == .start ? 0 : leg), value: phase)
        }
    }
}

/// A small rocket drawn from paths: pointed body, two fins, a window.
private struct RocketBody: View {
    var body: some View {
        ZStack {
            RocketFins().fill(Color(red: 0.89, green: 0.23, blue: 0.31))
            RocketHull().fill(LinearGradient(
                colors: [Color.white, Color(red: 0.82, green: 0.84, blue: 0.9)],
                startPoint: .leading,
                endPoint: .trailing
            ))
            RocketNose().fill(Color(red: 0.89, green: 0.23, blue: 0.31))
            GeometryReader { geo in
                Circle()
                    .fill(Color(red: 0.25, green: 0.5, blue: 0.9))
                    .overlay(Circle().strokeBorder(Color(red: 0.7, green: 0.75, blue: 0.85), lineWidth: 2))
                    .frame(width: geo.size.width * 0.32, height: geo.size.width * 0.32)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.46)
            }
        }
    }
}

private struct RocketHull: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.38), control: CGPoint(x: w * 0.82, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.86))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.86))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.38))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0), control: CGPoint(x: w * 0.18, y: h * 0.1))
        path.closeSubpath()
        return path
    }
}

private struct RocketNose: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addQuadCurve(to: CGPoint(x: w * 0.77, y: h * 0.24), control: CGPoint(x: w * 0.72, y: h * 0.07))
        path.addLine(to: CGPoint(x: w * 0.23, y: h * 0.24))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0), control: CGPoint(x: w * 0.28, y: h * 0.07))
        path.closeSubpath()
        return path
    }
}

private struct RocketFins: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.2, y: h * 0.52))
        path.addLine(to: CGPoint(x: 0, y: h * 0.92))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.86))
        path.closeSubpath()
        path.move(to: CGPoint(x: w * 0.8, y: h * 0.52))
        path.addLine(to: CGPoint(x: w, y: h * 0.92))
        path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.86))
        path.closeSubpath()
        return path
    }
}

/// The flame trail: a long teardrop that fades from white-hot to orange to nothing.
private struct RocketTrail: View {
    var body: some View {
        ZStack {
            TrailShape()
                .fill(LinearGradient(
                    colors: [Color(red: 1.0, green: 0.5, blue: 0.12), Color(red: 1.0, green: 0.3, blue: 0.1).opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            TrailShape()
                .fill(LinearGradient(
                    colors: [Color(red: 1.0, green: 0.88, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .scaleEffect(x: 0.6, y: 0.7, anchor: .top)
            TrailShape()
                .fill(LinearGradient(
                    colors: [Color.white, Color(red: 1.0, green: 0.9, blue: 0.6).opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .scaleEffect(x: 0.3, y: 0.4, anchor: .top)
        }
    }
}

private struct TrailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h), control: CGPoint(x: w * 0.95, y: h * 0.55))
        path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: w * 0.05, y: h * 0.55))
        path.closeSubpath()
        return path
    }
}
