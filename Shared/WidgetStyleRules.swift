import Foundation

// Pure rules behind the widget looks. Foundation only, compiled into the app and the widget extension.

/// The looks a widget can wear. The default, `gradient`, follows the Zalla accent.
enum WidgetLookKey: String, CaseIterable, Equatable {
    case gradient
    case midnight
    case aurora
    case glass
    case paper

    var title: String {
        switch self {
        case .gradient: return "Accent gradient"
        case .midnight: return "Midnight"
        case .aurora: return "Aurora"
        case .glass: return "Glass"
        case .paper: return "Paper"
        }
    }

    static let defaultLook = WidgetLookKey.gradient
}

enum WidgetTileRules {
    /// The letter on a favorite's tile: the first letter or digit of its title, without a leading "www.".
    static func initial(of title: String) -> String {
        let cleaned = title.lowercased().hasPrefix("www.") ? String(title.dropFirst(4)) : title
        for character in cleaned where character.isLetter || character.isNumber {
            return String(character).uppercased()
        }
        return "Z"
    }

    /// A favorite saved with the plain globe (or no icon) shows its letter. One with a chosen icon shows that icon.
    static func showsInitial(symbolName: String) -> Bool {
        symbolName.isEmpty || symbolName == "globe"
    }

    /// Which tile color a title gets. A fixed hash (not Swift's random one), so a tile keeps its color between
    /// reloads and between the app and the widget.
    static func colorIndex(for title: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt32 = 5381
        for scalar in title.lowercased().unicodeScalars {
            hash = (hash &* 33) &+ scalar.value
        }
        return Int(hash % UInt32(count))
    }
}

enum WidgetRingRules {
    struct Segment: Equatable {
        let index: Int
        let start: Double
        let end: Double
    }

    /// Arcs of a ring (0 to 1 around the circle) for the given counts, skipping zeros. A little gap separates arcs
    /// when more than one has a share. No counts at all gives no arcs.
    static func segments(_ values: [Int], gap: Double = 0.03) -> [Segment] {
        let total = values.reduce(0, +)
        guard total > 0 else { return [] }
        let shown = values.filter { $0 > 0 }.count
        var result: [Segment] = []
        var cursor = 0.0
        for (index, value) in values.enumerated() where value > 0 {
            let fraction = Double(value) / Double(total)
            let inset = shown > 1 ? min(gap, fraction / 3) / 2 : 0
            result.append(Segment(index: index, start: cursor + inset, end: cursor + fraction - inset))
            cursor += fraction
        }
        return result
    }
}
