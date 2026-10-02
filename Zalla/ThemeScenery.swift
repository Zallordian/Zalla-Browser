import Foundation

// Timing and scenery for the Volcano, Deep Ocean, Retro Arcade, Neon City, Arctic, and Cherry Blossom transitions.
// Plain math on fractions of the screen, with seeded random numbers, so the drawing is the same every time
// and everything here can be tested without a screen. The drawing lives in ThemeTransitionViews.swift.

// MARK: - Volcano

enum VolcanoLava {
    /// Where the lava front is, in screen heights up from the bottom. It passes 1 before the middle,
    /// so the whole screen is covered when the back edge starts to rise.
    static func front(_ progress: Double) -> Double {
        1.2 * TransitionCurve.smooth(progress / 0.55)
    }

    /// Where the lava's back edge is, in screen heights up from the bottom. It follows the front and clears the page
    /// upward, passing 1 by the end.
    static func back(_ progress: Double) -> Double {
        1.25 * TransitionCurve.smooth((progress - 0.45) / 0.55)
    }

    /// A ragged, slowly moving edge. Returns a small offset in screen heights, never more than `edgeAmplitude`.
    static let edgeAmplitude = 0.045

    static func edgeWave(x: Double, progress: Double, seed: Double) -> Double {
        let a = sin(x * 7.0 + seed + progress * 9.0)
        let b = 0.5 * sin(x * 17.0 + seed * 1.7 - progress * 13.0)
        let c = 0.25 * sin(x * 31.0 + seed * 2.3 + progress * 5.0)
        return edgeAmplitude * (a + b + c) / 1.75
    }

    /// A spark thrown off the leading edge of the lava.
    struct Spark: Equatable {
        /// Horizontal start, as a fraction of the width.
        var x: Double
        /// Progress at which it leaves the lava.
        var spawn: Double
        /// How long it lasts, as a fraction of the whole transition.
        var life: Double
        /// Screen heights it climbs over its life.
        var rise: Double
        /// Screen widths it drifts sideways over its life.
        var drift: Double
        /// Radius in points.
        var size: Double
        /// 0 to 1. Picks between yellow and orange.
        var heat: Double
    }

    static let sparkCount = 44

    static let sparks: [Spark] = {
        var generator = SeededGenerator(seed: 1883)
        return (0..<sparkCount).map { i in
            Spark(
                x: Double.random(in: 0.03...0.97, using: &generator),
                spawn: 0.04 + 0.5 * (Double(i) + Double.random(in: 0...0.9, using: &generator)) / Double(sparkCount),
                life: Double.random(in: 0.16...0.3, using: &generator),
                rise: Double.random(in: 0.12...0.4, using: &generator),
                drift: Double.random(in: -0.08...0.08, using: &generator),
                size: Double.random(in: 1.2...3.2, using: &generator),
                heat: Double.random(in: 0...1, using: &generator)
            )
        }
    }()

    /// Where a spark is at a moment, as fractions of the screen (y from the top), plus its opacity.
    /// Nil before it is thrown and after it has burned out.
    struct SparkState: Equatable {
        var x: Double
        var y: Double
        var alpha: Double
    }

    static func state(of spark: Spark, progress: Double) -> SparkState? {
        let age = (progress - spark.spawn) / spark.life
        guard age >= 0, age <= 1 else { return nil }
        let start = 1 - min(front(spark.spawn), 1.0)
        let climb = TransitionCurve.easeOutCubic(age)
        let y = start - spark.rise * climb
        return SparkState(
            x: spark.x + spark.drift * age,
            y: y,
            alpha: 1 - TransitionCurve.easeInCubic(age)
        )
    }

    /// A slow ember that floats up through the whole transition.
    struct Ember: Equatable {
        var x: Double
        var startY: Double
        /// Screen heights climbed over the whole transition.
        var rise: Double
        var sway: Double
        var phase: Double
        var size: Double
        var heat: Double
    }

    static let emberCount = 26

    static let embers: [Ember] = {
        var generator = SeededGenerator(seed: 9001)
        return (0..<emberCount).map { _ in
            Ember(
                x: Double.random(in: 0.02...0.98, using: &generator),
                startY: Double.random(in: 0.55...1.1, using: &generator),
                rise: Double.random(in: 0.35...0.8, using: &generator),
                sway: Double.random(in: 0.01...0.04, using: &generator),
                phase: Double.random(in: 0...(2 * Double.pi), using: &generator),
                size: Double.random(in: 1.4...3.8, using: &generator),
                heat: Double.random(in: 0...1, using: &generator)
            )
        }
    }()

    static func position(of ember: Ember, progress: Double) -> (x: Double, y: Double) {
        let x = ember.x + ember.sway * sin(ember.phase + progress * 2 * Double.pi * 1.5)
        let y = ember.startY - ember.rise * TransitionCurve.clamp(progress)
        return (x, y)
    }

    /// Embers glow in with the lava and burn out toward the end.
    static func emberAlpha(_ progress: Double) -> Double {
        sin(Double.pi * TransitionCurve.clamp(progress))
    }
}

// MARK: - Deep Ocean

enum OceanWave {
    /// How far across the water has reached, in screen widths from the left edge. It rolls past 1 to cover the screen,
    /// holds for a beat, then pulls back to the left and off the screen.
    static func reach(_ progress: Double) -> Double {
        let x = TransitionCurve.clamp(progress)
        if x < 0.5 {
            return 1.22 * TransitionCurve.easeOutCubic(x / 0.5)
        }
        if x < 0.58 { return 1.22 }
        return 1.22 * (1 - TransitionCurve.smooth((x - 0.58) / 0.42))
    }

    /// The edge of the wave is not straight: a swell that moves down the screen. A small offset in screen widths,
    /// never more than `edgeAmplitude`. `y` is a fraction of the height.
    static let edgeAmplitude = 0.06

    static func edgeSwell(y: Double, progress: Double) -> Double {
        let a = sin(y * 9.0 + progress * 11.0)
        let b = 0.45 * sin(y * 23.0 - progress * 17.0)
        return edgeAmplitude * (a + b) / 1.45
    }

    /// How strong the foam along the edge is. It is thickest while the wave is moving.
    static func foam(_ progress: Double) -> Double {
        sin(Double.pi * TransitionCurve.clamp(progress)) * 0.6 + 0.4
    }

    /// How much of the screen the water covers, 0 to 1. Bubbles and light only show while it does.
    static func depth(_ progress: Double) -> Double {
        TransitionCurve.smooth((reach(progress) - 0.2) / 0.9)
    }

    struct Bubble: Equatable {
        var x: Double
        var startY: Double
        var rise: Double
        var radius: Double
        var sway: Double
        var phase: Double
    }

    static let bubbleCount = 30

    static let bubbles: [Bubble] = {
        var generator = SeededGenerator(seed: 606)
        return (0..<bubbleCount).map { _ in
            Bubble(
                x: Double.random(in: 0.04...0.96, using: &generator),
                startY: Double.random(in: 0.7...1.15, using: &generator),
                rise: Double.random(in: 0.4...0.95, using: &generator),
                radius: Double.random(in: 2.5...11, using: &generator),
                sway: Double.random(in: 0.008...0.03, using: &generator),
                phase: Double.random(in: 0...(2 * Double.pi), using: &generator)
            )
        }
    }()

    static func position(of bubble: Bubble, progress: Double) -> (x: Double, y: Double) {
        let x = bubble.x + bubble.sway * sin(bubble.phase + progress * 2 * Double.pi * 2)
        let y = bubble.startY - bubble.rise * TransitionCurve.clamp(progress)
        return (x, y)
    }

    /// A shaft of light from the surface. Positions are fractions of the width at the top; it slants to the right.
    struct Ray: Equatable {
        var x: Double
        var width: Double
        var slant: Double
        var alpha: Double
        var phase: Double
    }

    static let rayCount = 6

    static let rays: [Ray] = {
        var generator = SeededGenerator(seed: 311)
        return (0..<rayCount).map { i in
            Ray(
                x: (Double(i) + Double.random(in: 0.1...0.9, using: &generator)) / Double(rayCount),
                width: Double.random(in: 0.05...0.13, using: &generator),
                slant: Double.random(in: 0.18...0.34, using: &generator),
                alpha: Double.random(in: 0.12...0.26, using: &generator),
                phase: Double.random(in: 0...(2 * Double.pi), using: &generator)
            )
        }
    }()

    /// The rays sway slowly: a small horizontal offset in screen widths.
    static func raySway(_ ray: Ray, progress: Double) -> Double {
        0.02 * sin(ray.phase + progress * 2 * Double.pi)
    }
}

// MARK: - Retro Arcade

enum ArcadeDissolve {
    /// Columns of blocks across the screen. Rows follow from the screen shape, so blocks stay square.
    static let columns = 12

    /// How many rows it takes to cover a screen of this shape.
    static func rows(width: Double, height: Double) -> Int {
        guard width > 0, height > 0 else { return 1 }
        let cell = width / Double(columns)
        return max(1, Int((height / cell).rounded(.up)))
    }

    /// A stable number from 0 to 1 for one block. A block turns on once the cover passes its number.
    static func threshold(col: Int, row: Int) -> Double {
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: col &* 7919 &+ row &* 104729 &+ 17))
        return Double.random(in: 0..<1, using: &generator)
    }

    /// Which of the three arcade colors a block takes, 0 to 2.
    static func colorIndex(col: Int, row: Int) -> Int {
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: col &* 31337 &+ row &* 7727 &+ 5))
        return Int.random(in: 0..<3, using: &generator)
    }

    /// How much of the screen is covered, 0 to just over 1. Rises to full by the middle, holds, then clears again.
    static func cover(_ progress: Double) -> Double {
        let x = TransitionCurve.clamp(progress)
        if x < 0.46 { return 1.04 * TransitionCurve.smooth(x / 0.46) }
        if x < 0.56 { return 1.04 }
        return 1.04 * (1 - TransitionCurve.smooth((x - 0.56) / 0.44))
    }

    static func isOn(col: Int, row: Int, progress: Double) -> Bool {
        threshold(col: col, row: row) < cover(progress)
    }

    /// Where the bright CRT scan bar is, as a fraction of the height from the top. It sweeps down once.
    static func scanBar(_ progress: Double) -> Double {
        -0.1 + 1.2 * TransitionCurve.clamp(progress)
    }

    /// How visible the scanlines are: strongest while the screen is covered.
    static func scanlineAlpha(_ progress: Double) -> Double {
        0.1 + 0.2 * TransitionCurve.smooth(cover(progress))
    }

    /// Points between scanlines.
    static let scanlineSpacing = 3.0

    struct Star: Equatable {
        var x: Double
        var y: Double
        /// Blocks per side, 1 or 2 pixels of the star grid.
        var pixels: Int
        /// 0 pink, 1 blue, 2 yellow.
        var color: Int
        var phase: Double
    }

    static let starCount = 36

    static let stars: [Star] = {
        var generator = SeededGenerator(seed: 8086)
        return (0..<starCount).map { i in
            Star(
                x: Double.random(in: 0.03...0.97, using: &generator),
                y: Double.random(in: 0.02...0.98, using: &generator),
                pixels: Int.random(in: 1...2, using: &generator),
                color: i % 3,
                phase: Double.random(in: 0...(2 * Double.pi), using: &generator)
            )
        }
    }()

    /// Stars blink on and off in steps, like a small display. 0 to 1.
    static func twinkle(_ star: Star, progress: Double) -> Double {
        let value = sin(star.phase + progress * 2 * Double.pi * 3)
        return value > -0.2 ? 1 : 0.25
    }

    /// Stars show while the screen is covered.
    static func starAlpha(_ progress: Double) -> Double {
        TransitionCurve.smooth((cover(progress) - 0.5) / 0.5)
    }
}

// MARK: - Neon City

enum NeonCity {
    /// Where the leading edge of the neon wipe is, in screen widths from the left. Passes 1 before the middle.
    static func front(_ progress: Double) -> Double {
        1.15 * TransitionCurve.smooth(progress / 0.55)
    }

    /// Where the trailing edge is. It follows the front and clears the screen to the right.
    static func back(_ progress: Double) -> Double {
        1.2 * TransitionCurve.smooth((progress - 0.45) / 0.55)
    }

    /// A neon sign that stutters: 1 most of the time, with brief dips. Always between `flickerFloor` and 1, so the
    /// wipe never disappears while it covers the page.
    static let flickerFloor = 0.5

    static func flicker(_ progress: Double) -> Double {
        let x = TransitionCurve.clamp(progress)
        let stutter = sin(x * 61.0) * sin(x * 37.0 + 0.6)
        return stutter > 0.72 ? flickerFloor : 1.0
    }

    /// Fractions of the screen height where the horizontal neon tubes sit, and which color each takes (0 magenta, 1 cyan).
    struct Tube: Equatable {
        var y: Double
        var tone: Int
    }

    static let tubes: [Tube] = [
        Tube(y: 0.14, tone: 0), Tube(y: 0.33, tone: 1), Tube(y: 0.52, tone: 0), Tube(y: 0.71, tone: 1), Tube(y: 0.9, tone: 0)
    ]

    /// A streak of light that races across behind the front.
    struct Streak: Equatable {
        /// Fraction of the screen height.
        var y: Double
        /// Fraction of the screen width.
        var length: Double
        /// Progress at which it sets off.
        var delay: Double
        /// How much progress it takes to cross.
        var travel: Double
        /// Points.
        var thickness: Double
        /// 0 magenta, 1 cyan.
        var tone: Int
    }

    static let streakCount = 18

    static let streaks: [Streak] = {
        var generator = SeededGenerator(seed: 2077)
        return (0..<streakCount).map { i in
            Streak(
                y: Double.random(in: 0.03...0.97, using: &generator),
                length: Double.random(in: 0.15...0.45, using: &generator),
                delay: Double.random(in: 0...0.4, using: &generator),
                travel: Double.random(in: 0.25...0.45, using: &generator),
                thickness: Double.random(in: 1.5...4.5, using: &generator),
                tone: i % 2
            )
        }
    }()

    /// Where the head of a streak is, in screen widths from the left. Nil before it sets off and after it has crossed.
    static func head(of streak: Streak, progress: Double) -> Double? {
        let u = (progress - streak.delay) / streak.travel
        guard u >= 0, u <= 1 else { return nil }
        return -0.05 + (1.1 + streak.length) * TransitionCurve.easeOutCubic(u)
    }

    /// Streaks fade in and out over their crossing.
    static func streakAlpha(of streak: Streak, progress: Double) -> Double {
        let u = TransitionCurve.clamp((progress - streak.delay) / streak.travel)
        return sin(Double.pi * u)
    }

    /// Points between scanlines.
    static let scanlineSpacing = 3.0
    static let scanlineAlpha = 0.16
}

// MARK: - Arctic

enum ArcticFrost {
    /// How much of the screen is frozen, 0 to just over 1: spreads by the middle, holds a beat, then melts back.
    static func cover(_ progress: Double) -> Double {
        let x = TransitionCurve.clamp(progress)
        if x < 0.5 { return 1.04 * TransitionCurve.easeOutCubic(x / 0.5) }
        if x < 0.58 { return 1.04 }
        return 1.04 * (1 - TransitionCurve.smooth((x - 0.58) / 0.42))
    }

    /// Radius of the ice growing from each corner, as a fraction of the screen diagonal. The soft edge takes the
    /// outer quarter, so the screen is solid ice once the cover passes 1.
    static let radiusPerCover = 0.7

    static func radius(_ progress: Double) -> Double {
        radiusPerCover * cover(progress)
    }

    /// The fraction of the radius that is fully opaque.
    static let solidFraction = 0.75

    /// A line of frost growing from a corner. Angle is within the quarter pointing into the screen.
    struct Arm: Equatable {
        /// 0 top left, 1 top right, 2 bottom left, 3 bottom right.
        var corner: Int
        /// Radians from the screen edge, 0 to pi/2.
        var angle: Double
        /// Fraction of the diagonal at full growth.
        var length: Double
        /// A short branch halfway along, as a fraction of the arm.
        var branch: Double
    }

    static let armCount = 28

    static let arms: [Arm] = {
        var generator = SeededGenerator(seed: 273)
        return (0..<armCount).map { i in
            Arm(
                corner: i % 4,
                angle: Double.random(in: 0.08...1.5, using: &generator),
                length: Double.random(in: 0.18...0.5, using: &generator),
                branch: Double.random(in: 0.25...0.5, using: &generator)
            )
        }
    }()

    /// A glint of light on the ice.
    struct Sparkle: Equatable {
        var x: Double
        var y: Double
        /// Points from the center to the tip.
        var size: Double
        var phase: Double
    }

    static let sparkleCount = 26

    static let sparkles: [Sparkle] = {
        var generator = SeededGenerator(seed: 5150)
        return (0..<sparkleCount).map { _ in
            Sparkle(
                x: Double.random(in: 0.04...0.96, using: &generator),
                y: Double.random(in: 0.03...0.97, using: &generator),
                size: Double.random(in: 4...12, using: &generator),
                phase: Double.random(in: 0...(2 * Double.pi), using: &generator)
            )
        }
    }()

    /// How bright a sparkle is, 0 to 1. Each one twinkles at its own time and only while there is ice.
    static func glint(_ sparkle: Sparkle, progress: Double) -> Double {
        let pulse = max(0, sin(sparkle.phase + progress * 2 * Double.pi * 3))
        return pulse * TransitionCurve.smooth((cover(progress) - 0.4) / 0.6)
    }

    /// A snow speck drifting down.
    struct Flake: Equatable {
        var x: Double
        var startY: Double
        /// Screen heights fallen over the whole transition.
        var fall: Double
        var sway: Double
        var phase: Double
        var size: Double
    }

    static let flakeCount = 30

    static let flakes: [Flake] = {
        var generator = SeededGenerator(seed: 1212)
        return (0..<flakeCount).map { _ in
            Flake(
                x: Double.random(in: 0.02...0.98, using: &generator),
                startY: Double.random(in: -0.2...0.6, using: &generator),
                fall: Double.random(in: 0.3...0.7, using: &generator),
                sway: Double.random(in: 0.01...0.035, using: &generator),
                phase: Double.random(in: 0...(2 * Double.pi), using: &generator),
                size: Double.random(in: 1.2...3.2, using: &generator)
            )
        }
    }()

    static func position(of flake: Flake, progress: Double) -> (x: Double, y: Double) {
        let x = flake.x + flake.sway * sin(flake.phase + progress * 2 * Double.pi * 2)
        let y = flake.startY + flake.fall * TransitionCurve.clamp(progress)
        return (x, y)
    }
}

// MARK: - Cherry Blossom

enum BlossomSwirl {
    /// A petal on its way across. Positions are fractions of the screen.
    struct Petal: Equatable {
        /// Vertical center of its path.
        var baseY: Double
        /// How far it swings up and down.
        var amplitude: Double
        /// Swings over the crossing.
        var turns: Double
        var phase: Double
        /// Progress at which it sets off.
        var delay: Double
        /// How much progress it takes to cross.
        var travel: Double
        /// Points, the long side of the petal.
        var size: Double
        /// Radians of spin over the crossing.
        var spin: Double
        /// 0 to 1. Picks between pale and deeper pink.
        var tone: Double
    }

    static let petalCount = 64

    static let petals: [Petal] = {
        var generator = SeededGenerator(seed: 1603)
        return (0..<petalCount).map { _ in
            Petal(
                baseY: Double.random(in: 0.0...1.0, using: &generator),
                amplitude: Double.random(in: 0.04...0.2, using: &generator),
                turns: Double.random(in: 0.8...2.2, using: &generator),
                phase: Double.random(in: 0...(2 * Double.pi), using: &generator),
                delay: Double.random(in: 0...0.4, using: &generator),
                travel: Double.random(in: 0.4...0.6, using: &generator),
                size: Double.random(in: 14...30, using: &generator),
                spin: Double.random(in: 2...9, using: &generator),
                tone: Double.random(in: 0...1, using: &generator)
            )
        }
    }()

    struct PetalState: Equatable {
        var x: Double
        var y: Double
        var angle: Double
        var alpha: Double
    }

    /// Where a petal is, or nil before it sets off and after it has left. It travels left to right while it swirls.
    static func state(of petal: Petal, progress: Double) -> PetalState? {
        let u = (progress - petal.delay) / petal.travel
        guard u >= 0, u <= 1 else { return nil }
        let travelled = TransitionCurve.smooth(u)
        let x = -0.15 + 1.3 * travelled
        let y = petal.baseY + petal.amplitude * sin(petal.phase + u * 2 * Double.pi * petal.turns)
        let alpha = min(1, min(u / 0.1, (1 - u) / 0.1))
        return PetalState(x: x, y: y, angle: petal.phase + u * petal.spin, alpha: alpha)
    }

    /// A soft pink wash behind the petals, strongest at the middle so the page is covered, then it clears.
    static let veilPeak = 0.88

    static func veil(_ progress: Double) -> Double {
        veilPeak * TransitionCurve.smooth(1 - abs(2 * TransitionCurve.clamp(progress) - 1))
    }
}
