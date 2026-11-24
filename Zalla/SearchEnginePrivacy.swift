import Foundation

/// Redesign phase 3: a plain guide to how much each offered search engine collects, shown in setup and in Settings.
/// These are Zalla's own summaries of each company's public privacy policy on the date below. Keep the wording to
/// what a policy says the company collects or uses, and update `ratedOn` whenever a line changes.
enum SearchEnginePrivacy {
    /// When the ratings were last checked against the policies.
    static let ratedOn = "November 2026"

    enum Level: Int, CaseIterable, Comparable {
        /// Red: collects a lot.
        case collectsALot = 1
        /// Yellow: collects some.
        case collectsSome = 2
        /// Green: collects very little.
        case collectsLittle = 3

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String {
            switch self {
            case .collectsALot: return "Collects a lot"
            case .collectsSome: return "Collects some"
            case .collectsLittle: return "Collects very little"
            }
        }

        /// How full the bar is drawn, out of 1.
        var fill: Double { Double(rawValue) / 3 }

        /// Color name, mapped to a SwiftUI color in the view so this file stays Foundation only.
        var colorName: String {
            switch self {
            case .collectsALot: return "red"
            case .collectsSome: return "yellow"
            case .collectsLittle: return "green"
            }
        }
    }

    struct Rating: Equatable {
        let level: Level
        /// Build 53: one short line, shown on every card. Same facts as `reason`, just shorter.
        let summary: String
        /// The fuller line, shown on the selected card and in Settings.
        let reason: String
        let policyURL: URL
    }

    /// Nil for Custom URL, which could be any site.
    static func rating(for engine: SearchEngine) -> Rating? {
        switch engine {
        case .brave:
            return Rating(
                level: .collectsLittle,
                summary: "No profile, and your IP address isn't kept with searches.",
                reason: "Keeps search words without your IP address or device, and doesn't build a profile of you.",
                policyURL: URL(string: "https://search.brave.com/help/privacy-policy")!
            )
        case .duckDuckGo:
            return Rating(
                level: .collectsLittle,
                summary: "Doesn't keep your IP address. Ads follow the search, not you.",
                reason: "Doesn't save your IP address with your searches. Ads match what you searched, not who you are.",
                policyURL: URL(string: "https://duckduckgo.com/privacy")!
            )
        case .startpage:
            return Rating(
                level: .collectsLittle,
                summary: "Google results without your IP address. Part of System1, a marketing company.",
                reason: "Gets Google results without passing on your IP address, and doesn't log searches. Part of System1, a marketing company.",
                policyURL: URL(string: "https://www.startpage.com/en/privacy-policy/")!
            )
        case .kagi:
            return Rating(
                level: .collectsLittle,
                summary: "No ads, and searches aren't tied to your account.",
                reason: "No ads, and searches aren't linked to your account. You need a paid Kagi account to use it.",
                policyURL: URL(string: "https://kagi.com/privacy")!
            )
        case .ecosia:
            return Rating(
                level: .collectsSome,
                summary: "Passes your search and IP address to Bing or Google.",
                reason: "Sends your search and IP address to Bing or Google for results. Ecosia removes its own copy of your IP within a week.",
                policyURL: URL(string: "https://www.ecosia.org/privacy")!
            )
        case .bing:
            return Rating(
                level: .collectsALot,
                summary: "Keeps searches to personalize results and ads.",
                reason: "Microsoft keeps searches with identifiers and uses them to personalize results and ads.",
                policyURL: URL(string: "https://privacy.microsoft.com/privacystatement")!
            )
        case .google:
            return Rating(
                level: .collectsALot,
                summary: "Can link searches to your Google Account for ads.",
                reason: "Keeps your searches and can link them to your Google Account to personalize results and ads.",
                policyURL: URL(string: "https://policies.google.com/privacy")!
            )
        case .custom:
            return nil
        }
    }

    /// Shown for Custom URL in Settings.
    static let customNote = "Zalla can't rate a custom search site. Check that site's privacy policy."

    /// Engines in the order setup shows them: the ones that collect the least first, then the rest.
    /// Within a level the order stays as SearchEngine lists them, so the default comes first.
    static func setupOrder(_ engines: [SearchEngine]) -> [SearchEngine] {
        let indexed = engines.enumerated().map { ($0.offset, $0.element) }
        return indexed.sorted { lhs, rhs in
            let left = rating(for: lhs.1)?.level.rawValue ?? 0
            let right = rating(for: rhs.1)?.level.rawValue ?? 0
            if left != right { return left > right }
            if lhs.1 == SearchEngine.defaultEngine { return true }
            if rhs.1 == SearchEngine.defaultEngine { return false }
            return lhs.0 < rhs.0
        }.map(\.1)
    }

    enum Copy {
        static let title = "Choose how you search"
        static let enginesNote = "Your searches go to the engine you pick, and each one handles them differently."
        static let zallaPromiseTitle = "Zalla collects nothing"
        static let zallaPromise = "No account and no analytics. A search only leaves your iPhone when you tap Go."
        static let footer = "Based on each company's public privacy policy as of \(SearchEnginePrivacy.ratedOn). A guide, not a guarantee."
    }
}
