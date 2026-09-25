import Foundation

/// A control that can sit in a toolbar or the Quick Action fan. `address` is the pinned address pill.
enum ToolbarItemKind: String, Codable, CaseIterable, Identifiable {
    case address
    case back
    case forward
    case reload
    case share
    case tabs
    case newTab
    case bookmarks
    case addBookmark
    case reader
    case find
    case desktopSite
    case pageZoom
    case downloads
    case menu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .address: return "Address Bar"
        case .back: return "Back"
        case .forward: return "Forward"
        case .reload: return "Reload"
        case .share: return "Share"
        case .tabs: return "Tabs"
        case .newTab: return "New Tab"
        case .bookmarks: return "Bookmarks"
        case .addBookmark: return "Add Bookmark"
        case .reader: return "Reader"
        case .find: return "Find on Page"
        case .desktopSite: return "Desktop Site"
        case .pageZoom: return "Page Zoom"
        case .downloads: return "Downloads"
        case .menu: return "Menu"
        }
    }

    var symbolName: String {
        switch self {
        case .address: return "magnifyingglass"
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .reload: return "arrow.clockwise"
        case .share: return "square.and.arrow.up"
        case .tabs: return "square.on.square"
        case .newTab: return "plus"
        case .bookmarks: return "book"
        case .addBookmark: return "bookmark"
        case .reader: return "doc.plaintext"
        case .find: return "text.magnifyingglass"
        case .desktopSite: return "desktopcomputer"
        case .pageZoom: return "textformat.size"
        case .downloads: return "arrow.down.circle"
        case .menu: return "ellipsis"
        }
    }
}

/// Which list the toolbar editor is changing. Quick Action has separate bar slots and fan items.
enum ToolbarEditTarget: String, CaseIterable, Identifiable {
    case classic
    case compact
    case quickActionBar
    case quickActionFan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .compact: return "Compact"
        case .quickActionBar: return "Quick Action bar"
        case .quickActionFan: return "Quick Action fan"
        }
    }

    /// Most buttons that fit, not counting the address pill.
    var limit: Int {
        switch self {
        case .classic: return 6
        case .compact: return 4
        case .quickActionBar: return 2
        case .quickActionFan: return 7
        }
    }

    /// Menu must stay reachable: it is required everywhere except the Quick Action bar slots,
    /// because the Quick Action fan always carries it.
    var requiresMenu: Bool { self != .quickActionBar }

    var usesAddressPill: Bool { self == .compact }

    var style: ToolbarStyle {
        switch self {
        case .classic: return .classic
        case .compact: return .compact
        case .quickActionBar, .quickActionFan: return .quickAction
        }
    }

    static func forStyle(_ style: ToolbarStyle) -> ToolbarEditTarget {
        switch style {
        case .classic: return .classic
        case .compact: return .compact
        case .quickAction: return .quickActionBar
        }
    }
}

/// Ordered toolbar buttons for every style. Defaults match the built-in layouts exactly.
struct ToolbarLayout: Equatable, Codable {
    static let storageKey = "toolbarLayout"

    var classic: [ToolbarItemKind]
    var compact: [ToolbarItemKind]
    var quickActionBar: [ToolbarItemKind]
    var quickActionFan: [ToolbarItemKind]

    static let defaultClassic: [ToolbarItemKind] = [.back, .forward, .share, .tabs, .menu]
    static let defaultCompact: [ToolbarItemKind] = [.back, .forward, .address, .share, .menu]
    static let defaultQuickActionBar: [ToolbarItemKind] = [.tabs]
    static var defaultQuickActionFan: [ToolbarItemKind] {
        QuickActionItem.allCases.compactMap { ToolbarItemKind(rawValue: $0.rawValue) }
    }

    static var `default`: ToolbarLayout {
        ToolbarLayout(
            classic: defaultClassic,
            compact: defaultCompact,
            quickActionBar: defaultQuickActionBar,
            quickActionFan: defaultQuickActionFan
        )
    }

    init(classic: [ToolbarItemKind], compact: [ToolbarItemKind],
         quickActionBar: [ToolbarItemKind], quickActionFan: [ToolbarItemKind]) {
        self.classic = Self.sanitized(classic, for: .classic)
        self.compact = Self.sanitized(compact, for: .compact)
        self.quickActionBar = Self.sanitized(quickActionBar, for: .quickActionBar)
        self.quickActionFan = Self.sanitized(quickActionFan, for: .quickActionFan)
    }

    private enum CodingKeys: String, CodingKey {
        case classic, compact, quickActionBar, quickActionFan
    }

    /// Tolerates missing lists and unknown item names from other builds.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func list(_ key: CodingKeys, _ fallback: [ToolbarItemKind]) -> [ToolbarItemKind] {
            guard let raw = try? container.decodeIfPresent([String].self, forKey: key) else { return fallback }
            return raw.compactMap { ToolbarItemKind(rawValue: $0) }
        }
        self.init(
            classic: list(.classic, Self.defaultClassic),
            compact: list(.compact, Self.defaultCompact),
            quickActionBar: list(.quickActionBar, Self.defaultQuickActionBar),
            quickActionFan: list(.quickActionFan, Self.defaultQuickActionFan)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(classic.map(\.rawValue), forKey: .classic)
        try container.encode(compact.map(\.rawValue), forKey: .compact)
        try container.encode(quickActionBar.map(\.rawValue), forKey: .quickActionBar)
        try container.encode(quickActionFan.map(\.rawValue), forKey: .quickActionFan)
    }

    // MARK: - Rules

    /// Removes duplicates and misplaced address pills, keeps Menu where required, and enforces the limit.
    static func sanitized(_ items: [ToolbarItemKind], for target: ToolbarEditTarget) -> [ToolbarItemKind] {
        var seen = Set<ToolbarItemKind>()
        var result: [ToolbarItemKind] = []
        for item in items where !seen.contains(item) {
            if item == .address && !target.usesAddressPill { continue }
            seen.insert(item)
            result.append(item)
        }
        if target.requiresMenu && !result.contains(.menu) {
            result.append(.menu)
        }
        // Drop the last removable buttons until the list fits.
        while result.filter({ $0 != .address }).count > target.limit {
            guard let index = result.lastIndex(where: { $0 != .address && $0 != .menu }) else { break }
            result.remove(at: index)
        }
        if target.usesAddressPill && !result.contains(.address) {
            result.insert(.address, at: result.count / 2)
        }
        return result
    }

    func items(for target: ToolbarEditTarget) -> [ToolbarItemKind] {
        switch target {
        case .classic: return classic
        case .compact: return compact
        case .quickActionBar: return quickActionBar
        case .quickActionFan: return quickActionFan
        }
    }

    mutating func setItems(_ items: [ToolbarItemKind], for target: ToolbarEditTarget) {
        let clean = Self.sanitized(items, for: target)
        switch target {
        case .classic: classic = clean
        case .compact: compact = clean
        case .quickActionBar: quickActionBar = clean
        case .quickActionFan: quickActionFan = clean
        }
    }

    func buttonCount(for target: ToolbarEditTarget) -> Int {
        items(for: target).filter { $0 != .address }.count
    }

    func canAdd(to target: ToolbarEditTarget) -> Bool {
        buttonCount(for: target) < target.limit
    }

    func canRemove(_ kind: ToolbarItemKind, from target: ToolbarEditTarget) -> Bool {
        if kind == .address { return false }
        if kind == .menu && target.requiresMenu { return false }
        return true
    }

    /// Items that can still be added to `target`, in a stable order.
    func available(for target: ToolbarEditTarget) -> [ToolbarItemKind] {
        let current = items(for: target)
        return ToolbarItemKind.allCases.filter { $0 != .address && !current.contains($0) }
    }

    /// Adds before a trailing Menu so Menu stays at the end by default.
    mutating func add(_ kind: ToolbarItemKind, to target: ToolbarEditTarget) {
        var list = items(for: target)
        guard kind != .address, !list.contains(kind), canAdd(to: target) else { return }
        if list.last == .menu {
            list.insert(kind, at: list.count - 1)
        } else {
            list.append(kind)
        }
        setItems(list, for: target)
    }

    mutating func remove(atOffsets offsets: IndexSet, from target: ToolbarEditTarget) {
        let list = items(for: target)
        let kept = list.enumerated().filter { index, kind in
            !(offsets.contains(index) && canRemove(kind, from: target))
        }.map(\.element)
        setItems(kept, for: target)
    }

    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int, in target: ToolbarEditTarget) {
        let list = items(for: target)
        let moving = offsets.sorted().filter { list.indices.contains($0) }.map { list[$0] }
        var remaining = list.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let shift = offsets.filter { $0 < destination }.count
        let insertAt = min(max(destination - shift, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertAt)
        setItems(remaining, for: target)
    }

    mutating func reset(_ target: ToolbarEditTarget) {
        setItems(Self.default.items(for: target), for: target)
    }

    // MARK: - Compact split

    /// Compact buttons left of the address pill.
    var compactLeading: [ToolbarItemKind] {
        guard let index = compact.firstIndex(of: .address) else { return [] }
        return Array(compact[..<index])
    }

    /// Compact buttons right of the address pill.
    var compactTrailing: [ToolbarItemKind] {
        guard let index = compact.firstIndex(of: .address) else { return compact }
        return Array(compact[compact.index(after: index)...])
    }

    // MARK: - Storage

    static func decode(_ data: Data) -> ToolbarLayout {
        guard !data.isEmpty, let layout = try? JSONDecoder().decode(ToolbarLayout.self, from: data) else {
            return .default
        }
        return layout
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}
