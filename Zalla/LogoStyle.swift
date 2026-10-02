import Foundation

/// A color in sRGB, each part 0 to 1. Plain numbers so the logo rules can be tested without UIKit.
struct LogoRGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// Reads "E33B4F" or "#E33B4F". Anything else becomes Zalla red.
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self = LogoContrast.zallaRed
            return
        }
        self.init(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }

    /// This color with `other` laid over it at `amount` (0 keeps this color, 1 is all `other`).
    func mixed(with other: LogoRGB, amount: Double) -> LogoRGB {
        let t = min(max(amount, 0), 1)
        return LogoRGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }
}

/// Which Zalla logo the new tab page draws. Auto picks the one you can read.
enum LogoStyle: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case red = "Zalla red"
    case white = "White"
    case black = "Black"

    var id: String { rawValue }
    static let storageKey = "homeLogoStyle"
}

/// The three logo images in the asset catalog.
enum LogoVariant: Equatable {
    case red
    case white
    case black

    var assetName: String {
        switch self {
        case .red: return "ZallaMark"
        case .white: return "ZallaMarkWhite"
        case .black: return "ZallaMarkBlack"
        }
    }
}

enum LogoContrast {
    /// The red used by the theme and the app icon.
    static let zallaRed = LogoRGB(r: 227.0 / 255, g: 59.0 / 255, b: 79.0 / 255)
    /// What the red logo image actually looks like on average, for contrast math.
    static let logoRed = LogoRGB(r: 250.0 / 255, g: 67.0 / 255, b: 66.0 / 255)
    static let logoWhite = LogoRGB(r: 0.96, g: 0.95, b: 0.93)
    static let logoBlack = LogoRGB(r: 0.03, g: 0.03, b: 0.04)

    /// Below this contrast ratio the red logo gets lost, so Auto swaps it.
    static let minimumRedContrast = 2.0
    /// The white logo has to reach at least this on a red or orange background.
    static let minimumNeutralContrast = 3.0
    /// How near to Zalla red (0 identical, 1 opposite) a background has to be to hide the red logo.
    static let nearRedDistance = 0.28

    /// WCAG relative luminance.
    static func luminance(_ c: LogoRGB) -> Double {
        func channel(_ v: Double) -> Double {
            let s = min(max(v, 0), 1)
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    /// WCAG contrast ratio, 1 to 21.
    static func contrastRatio(_ a: LogoRGB, _ b: LogoRGB) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// A simple perceptual distance, 0 to about 1. Uses the "redmean" weighting so reds compare sensibly.
    static func distance(_ a: LogoRGB, _ b: LogoRGB) -> Double {
        let rMean = (a.r + b.r) / 2
        let dr = a.r - b.r
        let dg = a.g - b.g
        let db = a.b - b.b
        let squared = (2 + rMean) * dr * dr + 4 * dg * dg + (3 - rMean) * db * db
        return (squared / 9).squareRoot()
    }

    /// White or black, whichever reads better on this background.
    static func readableNeutral(on background: LogoRGB) -> LogoVariant {
        contrastRatio(logoWhite, background) >= contrastRatio(logoBlack, background) ? .white : .black
    }

    /// The logo to draw. A fixed choice wins; Auto keeps the red logo unless it would vanish, then uses white or black.
    static func variant(style: LogoStyle, background: LogoRGB) -> LogoVariant {
        switch style {
        case .red: return .red
        case .white: return .white
        case .black: return .black
        case .auto:
            if distance(zallaRed, background) < nearRedDistance {
                // On red and orange the white logo is the look, unless the spot is so bright that white fades too.
                return contrastRatio(logoWhite, background) >= minimumNeutralContrast ? .white : .black
            }
            return contrastRatio(logoRed, background) < minimumRedContrast ? readableNeutral(on: background) : .red
        }
    }

    /// Text and small icons drawn over a wallpaper. White is the look whenever it reads well enough,
    /// so the text matches a white logo; black only takes over when white would fade.
    static func isLightInkBetter(on background: LogoRGB) -> Bool {
        contrastRatio(logoWhite, background) >= minimumNeutralContrast || readableNeutral(on: background) == .white
    }

    /// Where a preset gradient sits behind the logo and the saying, as one color. `fraction` is how far
    /// along the gradient that spot is, 0 to 1. Stops are evenly spaced, like the gradient itself.
    static func gradientColor(hexes: [String], fraction: Double) -> LogoRGB {
        let colors = hexes.map { LogoRGB(hex: $0) }
        guard let first = colors.first else { return zallaRed }
        guard colors.count > 1 else { return first }
        let position = min(max(fraction, 0), 1) * Double(colors.count - 1)
        let lower = min(Int(position), colors.count - 2)
        return colors[lower].mixed(with: colors[lower + 1], amount: position - Double(lower))
    }

    /// How much of the accent wash reaches the spot behind the logo, per unit of wash intensity.
    /// The wash fades out going down, so by the logo it is about a third strength.
    static let washReach = 0.35
    /// Roughly how far down the gradient the logo and saying sit.
    static let contentFraction = 0.4

    /// The plain look: the system grouped background with the accent wash fading in from the top.
    static func standardBackground(darkMode: Bool, accent: LogoRGB, washIntensity: Double) -> LogoRGB {
        let base = darkMode ? LogoRGB(r: 0, g: 0, b: 0) : LogoRGB(r: 242.0 / 255, g: 242.0 / 255, b: 247.0 / 255)
        return base.mixed(with: accent, amount: washIntensity * washReach)
    }

    /// A photo is drawn with a 30 percent black layer on top.
    static func photoBackground(average: LogoRGB) -> LogoRGB {
        average.mixed(with: LogoRGB(r: 0, g: 0, b: 0), amount: 0.3)
    }
}
