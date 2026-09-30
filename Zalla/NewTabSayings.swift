import Foundation

/// The short lines shown on the new tab page. Each new tab and each launch gets a different one.
enum NewTabSayings {
    static let all: [String] = [
        "Where to next?",
        "Browse quietly.",
        "Nothing here but you.",
        "Start somewhere.",
        "No trackers were invited.",
        "Your corner of the internet.",
        "Private by default.",
        "Go wander.",
        "What are we looking up?",
        "Clean slate.",
        "Just you and the web.",
        "Curiosity welcome.",
        "Search without being followed.",
        "Pick a door.",
        "Fresh tab, clear head.",
        "Stays on your phone.",
        "Look something up.",
        "Take the long way.",
        "No ads came with this tab.",
        "Ready when you are.",
        "The internet, minus the noise.",
        "What's on your mind?",
        "Built around you.",
        "Quiet mode, always.",
        "Find something good."
    ]

    /// Shared deck for the running app.
    private static var deck = SayingDeck(lines: all)

    /// The next saying. No saying repeats until every one has been shown once.
    static func next() -> String {
        var generator = SystemRandomNumberGenerator()
        return deck.next(using: &generator)
    }
}

/// A shuffled deck of lines. It is reshuffled when empty, and the first card of a new deck never
/// equals the last card of the old one.
struct SayingDeck {
    let lines: [String]
    private(set) var remaining: [String] = []
    private(set) var last: String?

    init(lines: [String]) {
        self.lines = lines
    }

    mutating func next<G: RandomNumberGenerator>(using generator: inout G) -> String {
        guard !lines.isEmpty else { return "" }
        if remaining.isEmpty {
            remaining = lines.shuffled(using: &generator)
            if lines.count > 1, remaining.last == last {
                remaining.swapAt(0, remaining.count - 1)
            }
        }
        let choice = remaining.removeLast()
        last = choice
        return choice
    }
}
