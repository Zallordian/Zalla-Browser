import Foundation

/// An action that can sit in the top row of the main Menu sheet.
enum MenuTopRowItem: String, Codable, CaseIterable, Identifiable {
    case back
    case forward
    case reload
    case tabs
    case settings
    case share
    case bookmark
    case find
    case newTab
    case burn
    case downloads
    case home

    var id: String { rawValue }

    var title: String {
        switch self {
        case .back: return "Back"
        case .forward: return "Forward"
        case .reload: return "Reload"
        case .tabs: return "Tabs"
        case .settings: return "Settings"
        case .share: return "Share"
        case .bookmark: return "Bookmark"
        case .find: return "Find on Page"
        case .newTab: return "New Tab"
        case .burn: return "Burn It All"
        case .downloads: return "Downloads"
        case .home: return "Home"
        }
    }

    /// Short label that fits under an icon in a narrow cell.
    var shortTitle: String {
        switch self {
        case .find: return "Find"
        case .newTab: return "New tab"
        case .burn: return "Burn"
        default: return title
        }
    }

    var symbolName: String {
        switch self {
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .reload: return "arrow.clockwise"
        case .tabs: return "square.on.square"
        case .settings: return "gearshape"
        case .share: return "square.and.arrow.up"
        case .bookmark: return "bookmark"
        case .find: return "text.magnifyingglass"
        case .newTab: return "plus"
        case .burn: return "flame"
        case .downloads: return "arrow.down.circle"
        case .home: return "house"
        }
    }
}

/// The ordered top row of the Menu sheet. Pure value logic so it is easy to test.
/// Every action in the row also lives further down the Menu, so nothing becomes unreachable.
struct MenuTopRow: Equatable {
    static let storageKey = "menuTopRow"
    /// Most cells that fit across a phone without crowding the labels.
    static let maxItems = 6
    static let minItems = 1

    /// Build 26 default: Back, Forward, Reload, Share, Settings. Tabs lives in the bottom bar by default now and is
    /// still one tap away in the editor. The editor stores an unchanged row as empty data, so anyone who never
    /// customized it picks up this default on its own, and a real customization is never touched.
    static let defaultItems: [MenuTopRowItem] = [.back, .forward, .reload, .share, .settings]
    /// The row before Build 26, for tests and docs.
    static let legacyDefaultItems: [MenuTopRowItem] = [.back, .forward, .reload, .tabs, .settings]

    private(set) var items: [MenuTopRowItem]

    static var `default`: MenuTopRow { MenuTopRow(defaultItems) }

    init(_ items: [MenuTopRowItem]) {
        self.items = Self.sanitized(items)
    }

    /// Removes duplicates, caps the length, and falls back to the default row when nothing is left.
    static func sanitized(_ items: [MenuTopRowItem]) -> [MenuTopRowItem] {
        var seen = Set<MenuTopRowItem>()
        var result: [MenuTopRowItem] = []
        for item in items where !seen.contains(item) {
            seen.insert(item)
            result.append(item)
        }
        if result.count > maxItems {
            result = Array(result.prefix(maxItems))
        }
        return result.isEmpty ? defaultItems : result
    }

    // MARK: - Storage

    /// Stored as a JSON list of names, so an unknown name from another build is simply skipped.
    static func decode(_ data: Data) -> MenuTopRow {
        guard !data.isEmpty,
              let names = try? JSONDecoder().decode([String].self, from: data) else { return .default }
        return MenuTopRow(names.compactMap { MenuTopRowItem(rawValue: $0) })
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(items.map(\.rawValue))) ?? Data()
    }

    var isDefault: Bool { items == Self.defaultItems }

    // MARK: - Editing

    var canAdd: Bool { items.count < Self.maxItems }

    func canRemove(_ item: MenuTopRowItem) -> Bool {
        items.contains(item) && items.count > Self.minItems
    }

    /// Items that can still be added, in a stable order.
    var available: [MenuTopRowItem] {
        MenuTopRowItem.allCases.filter { !items.contains($0) }
    }

    mutating func add(_ item: MenuTopRowItem) {
        guard canAdd, !items.contains(item) else { return }
        items.append(item)
    }

    mutating func remove(_ item: MenuTopRowItem) {
        guard canRemove(item), let index = items.firstIndex(of: item) else { return }
        items.remove(at: index)
    }

    mutating func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) where items.indices.contains(index) {
            remove(items[index])
        }
    }

    /// Same meaning as SwiftUI's `move(fromOffsets:toOffset:)`.
    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.sorted().filter { items.indices.contains($0) }.map { items[$0] }
        var remaining = items.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let shift = offsets.filter { $0 < destination }.count
        let insertAt = min(max(destination - shift, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertAt)
        items = Self.sanitized(remaining)
    }

    mutating func reset() {
        items = Self.defaultItems
    }
}
