import Foundation

/// Redesign phase 3: the one list of what is free and what Zalla Unlock adds. Setup, the Unlock sheet, and Settings
/// read from here so they can't disagree. Only list things the code really gates behind `ZallaUnlock.shared`.
enum ZallaUnlockBenefits {
    struct Item: Identifiable, Equatable {
        let title: String
        let detail: String
        let symbolName: String
        var id: String { title }
    }

    // MARK: Rule counts, read from the bundled manifest so the numbers stay true after a blocklist update

    static func ruleCount(_ categories: [BlocklistCategory], manifest: BlocklistManifest?) -> Int {
        guard let manifest else { return 0 }
        return categories.reduce(0) { total, category in
            total + manifest.parts(for: category).reduce(0) { $0 + $1.rules }
        }
    }

    static var freeCategories: [BlocklistCategory] { BlocklistCategory.allCases.filter { !$0.requiresUnlock } }
    static var unlockCategories: [BlocklistCategory] { BlocklistCategory.allCases.filter(\.requiresUnlock) }

    /// "about 111,000", rounded down to the thousand so it never overstates. Nil when the count is unknown or tiny.
    static func approximate(_ count: Int) -> String? {
        guard count >= 1_000 else { return nil }
        let rounded = (count / 1_000) * 1_000
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        guard let text = formatter.string(from: NSNumber(value: rounded)) else { return nil }
        return "about \(text)"
    }

    // MARK: Lists

    static func freeItems(manifest: BlocklistManifest? = BlocklistManifest.load()) -> [Item] {
        let rules = approximate(ruleCount(freeCategories, manifest: manifest))
        return [
            Item(
                title: "Tracker and ad blocking",
                detail: rules.map { "Blocks known trackers and common ad networks, \($0) rules." }
                    ?? "Blocks known trackers and common ad networks.",
                symbolName: "shield.lefthalf.filled"
            ),
            Item(title: "Privacy Shield", detail: "Cleans tracking out of links and trims what sites learn about where you came from.", symbolName: "lock.shield"),
            Item(title: "HTTPS-Only Mode", detail: "Tries the secure version of every site first.", symbolName: "lock"),
            Item(title: "Cookie banner closing", detail: "Picks reject or necessary only, and never presses accept.", symbolName: "xmark.seal"),
            Item(title: "Burn It All and the Privacy Report", detail: "Wipe everything in one tap, and see what Zalla stopped.", symbolName: "flame")
        ]
    }

    static func unlockItems(manifest: BlocklistManifest? = BlocklistManifest.load()) -> [Item] {
        let rules = approximate(ruleCount(unlockCategories, manifest: manifest))
        var items = [
            Item(
                title: "Full ad blocking",
                detail: (rules.map { "\($0.prefix(1).uppercased() + $0.dropFirst()) more rules. " } ?? "")
                    + "They catch the ads the free list misses, hide leftover ad boxes, and hide cookie notices, newsletter popups, and social widgets.",
                symbolName: "shield.checkered"
            ),
            Item(title: "Your own blocking rules", detail: "Hide any element on a page, and keep your own block and allow lists.", symbolName: "eye.slash.circle"),
            Item(title: "Face ID for private tabs", detail: "Private tabs stay locked until you unlock them.", symbolName: "faceid"),
            Item(title: "Scheduled auto-clear", detail: "Clear history and website data on launch, daily, or weekly.", symbolName: "clock.arrow.circlepath"),
            Item(title: "Tab groups", detail: "Sort your tabs into named, colored groups.", symbolName: "rectangle.stack"),
            Item(title: "Listen to page", detail: "Have articles read aloud to you.", symbolName: "speaker.wave.2"),
            Item(title: "Edit PDFs", detail: "Fill forms, add text, sign, and highlight.", symbolName: "signature"),
            Item(title: "Per-site CSS", detail: "Restyle any site your way.", symbolName: "paintbrush"),
            Item(
                title: "Theme packs and extra accents",
                detail: "The Space, Jungle, Volcano, Deep Ocean, Retro Arcade, Neon City, Arctic, and Cherry Blossom packs with matching icons and transitions, extra new tab backgrounds, and \(ZallaThemeID.pro.count) more accents.",
                symbolName: "sparkles"
            )
        ]
        if FeatureFlags.videoSaverEnabled {
            items.append(Item(title: "Video Saver", detail: "Save plain video files from pages.", symbolName: "arrow.down.to.line"))
        }
        return items
    }

    enum Copy {
        static let title = "Get more out of Zalla"
        static let subtitle = "One purchase, yours to keep. No subscription."
        static let freeHeader = "Free, always"
        static let unlockHeader = "Zalla Unlock adds"
        static let notNow = "Not right now"
        static let restore = "Restore Purchase"
        static let smallPrint = "One-time purchase through your Apple Account. Blocking trackers and common ads stays free."
        static let unlocked = "You're all set. Zalla Unlock is on."
        static func buyTitle(price: String) -> String { "Unlock for \(price)" }
    }
}
