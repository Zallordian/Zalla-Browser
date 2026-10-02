import Foundation

/// Which full-screen theme transition to play.
enum ThemeTransitionKind: Equatable {
    /// A leaf curtain slides in from both sides, then back out.
    case jungle
    /// A rocket climbs the screen and its exhaust washes over the page.
    case space
}

/// How fast theme transitions play. Normal is about a second.
enum ThemeTransitionSpeed: String, CaseIterable, Identifiable {
    case slow = "Slow"
    case normal = "Normal"
    case fast = "Fast"

    var id: String { rawValue }
    static let storageKey = "themeTransitionSpeed"

    /// Multiplies the base length: Slow takes longer, Fast takes less.
    var factor: Double {
        switch self {
        case .slow: return 1.5
        case .normal: return 1.0
        case .fast: return 0.65
        }
    }

    init(stored: String?) {
        self = ThemeTransitionSpeed(rawValue: stored ?? "") ?? .normal
    }
}

/// What actually plays: the full transition, or a quick fade when Reduce Motion is on.
struct ThemeTransitionPlan: Equatable {
    enum Style: Equatable {
        case full
        case fade
    }

    static let baseDuration = 1.0
    static let fadeDuration = 0.35

    let kind: ThemeTransitionKind
    let style: Style
    /// Seconds from start to the last frame.
    let duration: Double

    /// Nil means nothing plays: the pack is not unlocked, or transitions are switched off.
    static func make(kind: ThemeTransitionKind, unlocked: Bool, enabled: Bool, reduceMotion: Bool,
                     speed: ThemeTransitionSpeed) -> ThemeTransitionPlan? {
        guard unlocked, enabled else { return nil }
        let style: Style = reduceMotion ? .fade : .full
        let base = style == .full ? baseDuration : fadeDuration
        return ThemeTransitionPlan(kind: kind, style: style, duration: base * speed.factor)
    }
}

/// Deterministic random numbers, so a drawing made from them looks the same every time and can be tested.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x2545F4914F6CDD1D &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// One leaf in a jungle layer. Positions and sizes are fractions: x and lengths of the layer width, y of its height.
struct LeafSpec: Equatable {
    var rootX: Double
    var rootY: Double
    var length: Double
    var width: Double
    /// Radians. 0 points toward the middle of the screen, positive tilts down.
    var angle: Double
    /// How far the leaf bows sideways, -1 to 1. Zero is a straight leaf.
    var curve: Double = 0
    /// Ratio of one side's bulge to the other's, so leaves are not mirror images. About 1.
    var asymmetry: Double = 1
    /// Radians. Offsets the sway so leaves do not move together.
    var phase: Double = 0
    /// 0 to 1. Picks between the two greens of the layer.
    var tone: Double = 0

    /// Where the tip lands, as a fraction of the layer width.
    var tipX: Double { rootX + length * cos(angle) }
}

enum JungleLeaves {
    static let layerCount = 3
    static let leafCounts = [16, 12, 9]

    /// The leaves for one layer (0 is the back one). Front layers get bigger leaves.
    static func leaves(layer: Int, mirrored: Bool) -> [LeafSpec] {
        let index = min(max(layer, 0), layerCount - 1)
        let count = leafCounts[index]
        var generator = SeededGenerator(seed: UInt64(index * 2 + (mirrored ? 1 : 0) + 1) * 7919)
        var result: [LeafSpec] = []
        for i in 0..<count {
            let rootY = (Double(i) + Double.random(in: 0.1...0.9, using: &generator)) / Double(count)
            let rootX = Double.random(in: 0.05...0.4, using: &generator)
            let tilt = Double.random(in: 0.1...0.75, using: &generator) * (i % 2 == 0 ? 1 : -1)
            var length = Double.random(in: 0.55...0.85, using: &generator) * (0.9 + 0.12 * Double(index))
            // Keep every tip inside the layer.
            length = min(length, (0.98 - rootX) / cos(tilt))
            let width = length * Double.random(in: 0.3...0.42, using: &generator)
            // Drawn after the original values, so leaf positions stay as they were.
            let curve = Double.random(in: -0.8...0.8, using: &generator)
            let asymmetry = Double.random(in: 0.72...1.32, using: &generator)
            let phase = Double.random(in: 0...(2 * Double.pi), using: &generator)
            let tone = Double.random(in: 0...1, using: &generator)
            result.append(LeafSpec(
                rootX: rootX, rootY: rootY, length: length, width: width, angle: tilt,
                curve: curve, asymmetry: asymmetry, phase: phase, tone: tone
            ))
        }
        return result
    }

    /// A slow rotation around the root while the curtain moves, in radians. Bigger for the front layers.
    static func sway(_ leaf: LeafSpec, progress: Double, layer: Int) -> Double {
        let amplitude = 0.04 + 0.02 * Double(min(max(layer, 0), layerCount - 1))
        return amplitude * sin(leaf.phase + progress * 2 * Double.pi * 1.25)
    }
}

/// Easing and timing for the full-screen theme transitions. Progress runs from 0 to 1 over the whole transition.
/// Plain math, so it is easy to test.
enum TransitionCurve {
    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    static func smooth(_ value: Double) -> Double {
        let x = clamp(value)
        return x * x * (3 - 2 * x)
    }

    static func easeOutCubic(_ value: Double) -> Double { 1 - pow(1 - clamp(value), 3) }

    static func easeInCubic(_ value: Double) -> Double { pow(clamp(value), 3) }

    /// How far a jungle layer has slid in, 0 (off screen) to 1 (in place). Back layers (0) move first going in and
    /// last going out, so the curtain has depth. Every layer is in place between 0.50 and 0.55.
    static func curtain(_ progress: Double, layer: Int, of count: Int) -> Double {
        let x = clamp(progress)
        let step = 0.05
        let index = Double(min(max(layer, 0), max(count, 1) - 1))
        let enterStart = step * index
        let enterLength = 0.40
        let leaveStart = 0.55 + step * (Double(max(count, 1) - 1) - index)
        let leaveLength = 0.35
        if x < enterStart + enterLength {
            return easeOutCubic((x - enterStart) / enterLength)
        }
        if x < leaveStart { return 1 }
        return 1 - easeInCubic((x - leaveStart) / leaveLength)
    }

    /// The Reduce Motion fade: the screen tints up to 0.85 at the middle and clears again.
    static func fadeOpacity(_ progress: Double) -> Double {
        0.85 * smooth(1 - abs(2 * clamp(progress) - 1))
    }
}

/// Timing and scenery for the Space launch.
enum SpaceFlight {
    /// The ship is gone off the top by this point; the glow lifts away after it.
    static let flightEnd = 0.74
    /// The glow starts to lift away upward here.
    static let liftStart = 0.62

    /// How far up the ship has climbed, 0 to 1. It eases off the pad and keeps accelerating, like a real launch.
    static func thrust(_ progress: Double) -> Double {
        let x = TransitionCurve.clamp(progress / flightEnd)
        return 0.3 * TransitionCurve.smooth(x) + 0.7 * pow(x, 2.2)
    }

    /// How far the glow has lifted away, 0 (still covering) to 1 (gone).
    static func lift(_ progress: Double) -> Double {
        let x = TransitionCurve.clamp((progress - liftStart) / (1 - liftStart))
        return TransitionCurve.smooth(x)
    }

    /// A puff of smoke left behind at one moment of the climb. Sizes and offsets are fractions of the screen width.
    struct Puff: Equatable {
        /// Progress at which it leaves the engine.
        var spawn: Double
        var offsetX: Double
        var driftX: Double
        var radius: Double
    }

    /// How long a puff lasts, as a fraction of the whole transition.
    static let puffLife = 0.34

    static let puffs: [Puff] = {
        var generator = SeededGenerator(seed: 4242)
        return (0..<14).map { i in
            Puff(
                spawn: 0.03 + 0.46 * (Double(i) + Double.random(in: 0...0.8, using: &generator)) / 14,
                offsetX: Double.random(in: -0.025...0.025, using: &generator),
                driftX: Double.random(in: -0.1...0.1, using: &generator),
                radius: Double.random(in: 0.035...0.07, using: &generator)
            )
        }
    }()

    /// A thin line of passing air that streaks down as the ship climbs. Fractions of the screen.
    struct Streak: Equatable {
        var x: Double
        var y: Double
        var length: Double
        var speed: Double
        var alpha: Double
    }

    static let streaks: [Streak] = {
        var generator = SeededGenerator(seed: 777)
        return (0..<14).map { _ in
            Streak(
                x: Double.random(in: 0.04...0.96, using: &generator),
                y: Double.random(in: 0...1, using: &generator),
                length: Double.random(in: 0.05...0.14, using: &generator),
                speed: Double.random(in: 1.2...2.4, using: &generator),
                alpha: Double.random(in: 0.12...0.3, using: &generator)
            )
        }
    }()
}

/// Burn It All: the fire effect, or a quick fade when Reduce Motion is on or the effect is switched off.
struct BurnEffectPlan: Equatable {
    enum Style: Equatable {
        case fire
        case fade
    }

    /// Flames rise, fill the screen, break apart, and fade to embers, in about two and a half seconds.
    static let fireDuration = 2.4
    static let fadeDuration = 0.3
    /// Set when Burn It All is confirmed and cleared once the wipe is done. If Zalla is closed in between,
    /// the next launch finishes the wipe and restores nothing.
    static let pendingKey = "burnPending"
    /// Settings, Privacy: the fire effect on or off. On by default; off plays the quick fade.
    static let animationKey = "burnAnimation"

    let style: Style
    let duration: Double

    static func animationEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: animationKey) as? Bool ?? true
    }

    static func make(reduceMotion: Bool, animated: Bool = true) -> BurnEffectPlan {
        (reduceMotion || !animated)
            ? BurnEffectPlan(style: .fade, duration: fadeDuration)
            : BurnEffectPlan(style: .fire, duration: fireDuration)
    }
}
