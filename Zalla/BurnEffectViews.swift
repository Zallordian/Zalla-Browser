import SwiftUI

/// The four burning edges of the screen as one shape. Flames grow in from every edge toward the middle as
/// `progress` goes from 0 to 1. `reach` scales how deep this layer goes, so three layers make a flame
/// with an orange tip, a yellow middle, and a dark charred edge behind it.
struct FireFrontShape: Shape {
    var progress: Double
    var reach: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let tonguesAcross = FlameTongues.make(count: 12, seed: 11)
    private static let tonguesDown = FlameTongues.make(count: 24, seed: 29)
    private static let tonguesBottom = FlameTongues.make(count: 12, seed: 47)
    private static let tonguesRight = FlameTongues.make(count: 24, seed: 83)

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0.001 else { return path }
        let w = rect.width, h = rect.height
        let eased = progress
        // A little past halfway, so the fronts overlap in the middle by the end.
        let depthY = h * 0.56 * eased * reach
        let depthX = w * 0.56 * eased * reach
        addEdge(&path, tongues: Self.tonguesAcross, length: w, depth: depthY) { along, d in CGPoint(x: along, y: d) }
        addEdge(&path, tongues: Self.tonguesBottom, length: w, depth: depthY) { along, d in CGPoint(x: along, y: h - d) }
        addEdge(&path, tongues: Self.tonguesDown, length: h, depth: depthX) { along, d in CGPoint(x: d, y: along) }
        addEdge(&path, tongues: Self.tonguesRight, length: h, depth: depthX) { along, d in CGPoint(x: w - d, y: along) }
        return path
    }

    /// One edge: a solid band along the edge with a tongue of flame rising from it for each tongue spec.
    private func addEdge(_ path: inout Path, tongues: [FlameTongue], length: CGFloat, depth: CGFloat,
                         point: (CGFloat, CGFloat) -> CGPoint) {
        let band = depth * 0.22
        path.move(to: point(0, 0))
        path.addLine(to: point(0, band))
        for tongue in tongues {
            let center = CGFloat(tongue.center) * length
            let half = CGFloat(tongue.halfWidth) * length
            let tipDepth = max(depth * CGFloat(tongue.height), band)
            let tip = point(center + CGFloat(tongue.lean) * half, tipDepth)
            path.addLine(to: point(center - half, band))
            path.addQuadCurve(to: tip, control: point(center - half * 0.15, tipDepth * 0.55))
            path.addQuadCurve(to: point(center + half, band), control: point(center + half * 0.9, tipDepth * 0.5))
        }
        path.addLine(to: point(length, band))
        path.addLine(to: point(length, 0))
        path.closeSubpath()
    }
}

/// Burn It All's full-screen effect: flames creep in from the outer edges toward the center and the browser
/// burns away. Three animated shapes and one fade, no timers, no network. With Reduce Motion it is a quick fade.
/// It only draws. The wipe and the exit happen in BrowserStore whether or not this ever appears.
struct BurnOverlay: View {
    let plan: BurnEffectPlan

    @State private var progress = 0.0
    @State private var covered = false
    @State private var settled = false

    var body: some View {
        ZStack {
            switch plan.style {
            case .fire:
                fire
            case .fade:
                Color(uiColor: .systemBackground)
                    .opacity(covered ? 0.96 : 0)
                    .animation(.easeInOut(duration: plan.duration), value: covered)
                    .ignoresSafeArea()
            }
            message
                .opacity(settled ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: settled)
        }
        .onAppear {
            progress = 1
            covered = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(plan.duration * 1_000_000_000))
                settled = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clearing everything. Zalla will close in a moment.")
    }

    private var fire: some View {
        let d = plan.duration
        return ZStack {
            // Heat first: the whole screen warms and darkens a little as the fronts close in.
            Color(red: 0.25, green: 0.04, blue: 0.02)
                .opacity(covered ? 0.6 : 0)
                .animation(.easeIn(duration: d), value: covered)
            FireFrontShape(progress: progress, reach: 1.0)
                .fill(Color(red: 1.0, green: 0.36, blue: 0.06))
                .shadow(color: Color(red: 1.0, green: 0.4, blue: 0.05).opacity(0.85), radius: 16)
            FireFrontShape(progress: progress, reach: 0.88)
                .fill(Color(red: 1.0, green: 0.72, blue: 0.16))
            FireFrontShape(progress: progress, reach: 0.74)
                .fill(Color(red: 0.12, green: 0.05, blue: 0.04))
            // The last stretch: everything left goes to ash, so the middle is covered when the fronts meet.
            Color(red: 0.1, green: 0.04, blue: 0.03)
                .opacity(covered ? 1 : 0)
                .animation(.easeIn(duration: d * 0.35).delay(d * 0.65), value: covered)
        }
        .animation(.easeIn(duration: d), value: progress)
        .ignoresSafeArea()
    }

    private var message: some View {
        let light = plan.style == .fire
        return VStack(spacing: 14) {
            FlameMark(size: 64)
            Text("Clearing everything")
                .font(.headline)
                .foregroundStyle(light ? Color.white : Color.primary)
            Text("Zalla will close in a moment. Open it again for a clean slate.")
                .font(.subheadline)
                .foregroundStyle(light ? Color.white.opacity(0.75) : Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
