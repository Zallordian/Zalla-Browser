import Foundation

/// The phases of the Burn It All fire effect, as fractions of its total time (0 at the start, 1 at the end).
/// Flames rise over the browser, fill the screen, break apart into single licks, then fade into embers on black.
/// Everything here is plain math, so the timing and shapes can be tested without drawing anything.
enum BurnPhase: Equatable {
    case rise
    case blaze
    case breakApart
    case embers
}

enum BurnFire {
    static let riseEnd = 0.30
    static let blazeEnd = 0.55
    static let breakEnd = 0.78

    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    /// How far along the effect is, 0 to 1, from when it started. Time alone decides it, so it can never restart.
    static func progress(startedAt: Date, now: Date, duration: Double) -> Double {
        guard duration > 0 else { return 1 }
        return clamp(now.timeIntervalSince(startedAt) / duration)
    }

    static func smooth(_ value: Double) -> Double {
        let x = clamp(value)
        return x * x * (3 - 2 * x)
    }

    static func phase(at t: Double) -> BurnPhase {
        let x = clamp(t)
        if x < riseEnd { return .rise }
        if x < blazeEnd { return .blaze }
        if x < breakEnd { return .breakApart }
        return .embers
    }

    /// How dark the browser underneath has become, 0 to 1. It chars while the flames rise, and is fully black by the embers.
    static func cover(at t: Double) -> Double {
        let x = clamp(t)
        if x < 0.5 { return 0.85 * smooth(x / 0.5) }
        return 0.85 + 0.15 * smooth((x - 0.5) / 0.25)
    }

    /// The overall strength of the fire light, 0 to 1: up with the rise, steady through the blaze, gone as the licks break apart.
    static func intensity(at t: Double) -> Double {
        let x = clamp(t)
        if x < riseEnd { return smooth(x / riseEnd) }
        if x < blazeEnd { return 1 }
        return 1 - smooth((x - blazeEnd) / (0.88 - blazeEnd))
    }

    /// The plain "Clearing browsing data..." label fades in as the embers go out.
    static func labelOpacity(at t: Double) -> Double {
        smooth((clamp(t) - 0.92) / 0.08)
    }

    // MARK: - Flame tongues

    /// One tongue of flame. Positions and sizes are fractions of the screen so the same fire fits every iPhone.
    struct Tongue: Equatable {
        /// Back row tongues are taller and darker; front row tongues are shorter and brighter.
        var row: Int
        /// Where the base sits across the screen, 0 to 1.
        var baseX: Double
        /// Width of the base as a fraction of the screen width.
        var width: Double
        /// Full height as a fraction of the screen height. Back tongues can reach past the top.
        var height: Double
        /// Sideways slant of the tip, in tongue widths.
        var lean: Double
        /// Radians. Offsets the swirl and flicker so tongues do not move together.
        var phase: Double
        /// How fast it flickers, radians per second.
        var speed: Double
        /// How deep the sawtooth teeth on its edges cut in, 0.1 to 0.4.
        var jag: Double
        /// 0 to 1. Later tongues start rising a little later.
        var delay: Double
        /// 0 to 1. Later tongues break loose a little later.
        var breakDelay: Double
        /// 0 to 1. How far the lick floats up once it breaks loose.
        var drift: Double
    }

    /// The fire is the same every time. 22 tongues in two rows.
    static let tongues: [Tongue] = makeTongues()

    private static func makeTongues() -> [Tongue] {
        var generator = SeededGenerator(seed: 1912)
        var result: [Tongue] = []
        let rows: [(count: Int, minHeight: Double, maxHeight: Double, width: Double)] = [
            (9, 1.0, 1.4, 0.30),
            (13, 0.62, 1.0, 0.22)
        ]
        for (row, spec) in rows.enumerated() {
            for i in 0..<spec.count {
                let spacing = 1.0 / Double(spec.count)
                let jitter = Double.random(in: -0.3...0.3, using: &generator) * spacing
                result.append(Tongue(
                    row: row,
                    baseX: (Double(i) + 0.5) * spacing + jitter,
                    width: spec.width * Double.random(in: 0.85...1.15, using: &generator),
                    height: Double.random(in: spec.minHeight...spec.maxHeight, using: &generator),
                    lean: Double.random(in: -0.6...0.6, using: &generator),
                    phase: Double.random(in: 0...(2 * Double.pi), using: &generator),
                    speed: Double.random(in: 7...12, using: &generator),
                    jag: Double.random(in: 0.12...0.38, using: &generator),
                    delay: Double.random(in: 0...1, using: &generator),
                    breakDelay: Double.random(in: 0...1, using: &generator),
                    drift: Double.random(in: 0...1, using: &generator)
                ))
            }
        }
        return result
    }

    /// How a tongue looks at one moment.
    struct TongueState: Equatable {
        /// 0 to 1: how much of its full size it has.
        var scale: Double
        /// How far it has floated up, as a fraction of the screen height.
        var lift: Double
        /// 0 to 1.
        var opacity: Double
    }

    static func state(of tongue: Tongue, at t: Double) -> TongueState {
        let x = clamp(t)
        let riseStart = tongue.delay * 0.18
        let grown = smooth((x - riseStart) / (riseEnd - riseStart))
        // Breaking apart: the tongue shrinks to a small lick, floats up, and fades.
        let breakStart = blazeEnd + tongue.breakDelay * 0.10
        let q = clamp((x - breakStart) / (breakEnd - blazeEnd))
        let scale = grown * (1 - 0.72 * q * q)
        let lift = q * (0.12 + 0.45 * tongue.drift)
        let opacity = 1 - smooth((q - 0.5) / 0.5)
        return TongueState(scale: scale, lift: lift, opacity: opacity)
    }

    struct Point: Equatable {
        var x: Double
        var y: Double
    }

    /// The outline of one tongue in its own space: x across the base from -0.5 to 0.5 (plus swirl), y from 0 at the base
    /// to about 1 at the tip. Straight edges with sawtooth teeth give the sharp, jagged look. It starts and ends on the
    /// base line, and the tip is the highest point. `time` is in seconds and drives the swirl and flicker.
    static func outline(of tongue: Tongue, time: Double, segments: Int = 9) -> [Point] {
        let n = max(segments, 3)
        let flicker = 1 + 0.05 * sin(time * tongue.speed * 1.7 + tongue.phase)
        func bend(_ s: Double) -> Double {
            let swirl = 0.26 * sin(tongue.phase + time * tongue.speed * 0.5 + s * 2.6)
            return (tongue.lean * pow(s, 1.5) + swirl * s)
        }
        func side(_ i: Int, sign: Double) -> Point {
            let s = Double(i) / Double(n)
            let half = 0.5 * pow(1 - s, 0.85)
            let odd = sign < 0 ? (i % 2 == 1) : (i % 2 == 0)
            let cut = (odd && i > 0 && i < n) ? tongue.jag : 0
            // Teeth also sit a touch lower, so the edge reads as a saw blade leaning up.
            let y = (s - (cut > 0 ? 0.035 : 0)) * flicker
            return Point(x: sign * half * (1 - cut) + bend(s), y: max(y, 0))
        }
        var points: [Point] = []
        for i in 0...n { points.append(side(i, sign: -1)) }
        var i = n - 1
        while i >= 0 {
            points.append(side(i, sign: 1))
            i -= 1
        }
        return points
    }

    // MARK: - Embers

    struct Ember: Equatable {
        var x: Double
        /// Where it starts, as a fraction of the screen height from the top.
        var y: Double
        /// Radius in points.
        var radius: Double
        /// How far up it floats, as a fraction of the screen height.
        var rise: Double
        /// Sideways wander in fractions of the screen width.
        var sway: Double
        var twinkle: Double
        /// 0 to 1. Later embers wake up later.
        var delay: Double
        /// 0 for red, 1 for orange.
        var warmth: Double
    }

    static let embers: [Ember] = makeEmbers()

    private static func makeEmbers() -> [Ember] {
        var generator = SeededGenerator(seed: 2025)
        return (0..<44).map { _ in
            Ember(
                x: Double.random(in: 0.03...0.97, using: &generator),
                y: Double.random(in: 0.25...1.0, using: &generator),
                radius: Double.random(in: 1.2...3.4, using: &generator),
                rise: Double.random(in: 0.08...0.3, using: &generator),
                sway: Double.random(in: -0.05...0.05, using: &generator),
                twinkle: Double.random(in: 0...(2 * Double.pi), using: &generator),
                delay: Double.random(in: 0...1, using: &generator),
                warmth: Double.random(in: 0...1, using: &generator)
            )
        }
    }

    struct EmberState: Equatable {
        var x: Double
        var y: Double
        var alpha: Double
    }

    /// Embers wake up as the licks break apart, float up, glow, and go out. All of them are out by the end.
    static func state(of ember: Ember, at t: Double) -> EmberState {
        let start = 0.62 + ember.delay * 0.12
        let life = clamp((t - start) / (1 - start))
        let envelope = clamp(life * 6) * pow(1 - life, 0.8)
        let flicker = 0.65 + 0.35 * sin(ember.twinkle + life * 14)
        return EmberState(
            x: ember.x + ember.sway * life,
            y: ember.y - ember.rise * life,
            alpha: clamp(envelope * flicker)
        )
    }
}
