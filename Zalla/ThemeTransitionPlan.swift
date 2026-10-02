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
            result.append(LeafSpec(rootX: rootX, rootY: rootY, length: length, width: width, angle: tilt))
        }
        return result
    }
}

/// Burn It All: the fire effect, or a quick fade when Reduce Motion is on.
struct BurnEffectPlan: Equatable {
    enum Style: Equatable {
        case fire
        case fade
    }

    static let fireDuration = 1.2
    static let fadeDuration = 0.3
    /// Set when Burn It All is confirmed and cleared once the wipe is done. If Zalla is closed in between,
    /// the next launch finishes the wipe and restores nothing.
    static let pendingKey = "burnPending"

    let style: Style
    let duration: Double

    static func make(reduceMotion: Bool) -> BurnEffectPlan {
        reduceMotion
            ? BurnEffectPlan(style: .fade, duration: fadeDuration)
            : BurnEffectPlan(style: .fire, duration: fireDuration)
    }
}

/// One tongue of flame along a burning edge. `center` and `halfWidth` are fractions of the edge length,
/// `height` is how far the tip reaches into the flame band (0 to 1), `lean` slants the tip sideways.
struct FlameTongue: Equatable {
    var center: Double
    var halfWidth: Double
    var height: Double
    var lean: Double
}

enum FlameTongues {
    /// Evenly spaced tongues that never overlap, with a little jitter so the edge looks alive.
    static func make(count: Int, seed: UInt64) -> [FlameTongue] {
        guard count > 0 else { return [] }
        var generator = SeededGenerator(seed: seed)
        let spacing = 1.0 / Double(count)
        return (0..<count).map { i in
            let jitter = Double.random(in: -0.1...0.1, using: &generator) * spacing
            return FlameTongue(
                center: (Double(i) + 0.5) * spacing + jitter,
                halfWidth: spacing * 0.5 * Double.random(in: 0.78...0.95, using: &generator),
                height: Double.random(in: 0.55...1.0, using: &generator),
                lean: Double.random(in: -0.5...0.5, using: &generator)
            )
        }
    }
}
