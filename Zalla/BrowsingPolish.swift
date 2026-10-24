import UIKit

/// Build 44: switches for the Safari style polish. Each key is new, so a missing value reads as the default (on).
enum BrowsingPolish {
    static let pillSwipeKey = "pillSwipeSwitchesTabs"
    static let snapshotsKey = "pageSnapshotPreviews"
    static let hapticsKey = "browsingHaptics"
    static let quietAccentKey = "safariBarQuietAccent"
    static let titleCrossfadeKey = "pillTitleCrossfade"

    static let pillSwipeDefault = true
    static let snapshotsDefault = true
    static let hapticsDefault = true
    static let quietAccentDefault = true
    static let titleCrossfadeDefault = true

    static var allKeys: [String] { [pillSwipeKey, snapshotsKey, hapticsKey, quietAccentKey, titleCrossfadeKey] }

    /// Reads a switch, treating a missing value as its default.
    static func isOn(_ key: String, default value: Bool, in defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else { return value }
        return defaults.bool(forKey: key)
    }

    static var snapshotsOn: Bool { isOn(snapshotsKey, default: snapshotsDefault) }
    static var hapticsOn: Bool { isOn(hapticsKey, default: hapticsDefault) }
}

/// The only three moments Build 44 adds a tap for: switching tabs, pull to refresh, and Back first appearing.
enum BrowsingHaptic {
    case tabSwitch, pullToRefresh, backAppeared

    static func shouldPlay(_ haptic: BrowsingHaptic, enabled: Bool) -> Bool { enabled }

    /// Back only counts as appearing when it was hidden a moment ago on the same tab, not when switching tabs.
    static func backAppeared(was: Bool, now: Bool, sameTab: Bool) -> Bool {
        sameTab && !was && now
    }

    static func play(_ haptic: BrowsingHaptic, enabled: Bool = BrowsingPolish.hapticsOn) {
        guard shouldPlay(haptic, enabled: enabled) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Swiping on the Safari style pill moves to the tab beside this one.
enum TabSwipe {
    /// Share of the screen width the pill has to travel, or a quick flick, to switch.
    static let commitFraction: Double = 0.28
    static let flickVelocity: Double = 600
    /// Dragging toward a side with no tab only gives a little, like a rubber band.
    static let edgeResistance: Double = 0.25

    /// The tab a swipe lands on. A swipe to the left (negative) goes to the next tab, to the right the previous one.
    static func neighbor<ID: Equatable>(in ids: [ID], current: ID, translation: Double) -> ID? {
        guard translation != 0, let index = ids.firstIndex(of: current) else { return nil }
        let target = translation < 0 ? index + 1 : index - 1
        return ids.indices.contains(target) ? ids[target] : nil
    }

    static func shouldCommit(translation: Double, predictedEnd: Double, width: Double, hasNeighbor: Bool) -> Bool {
        guard hasNeighbor, width > 0 else { return false }
        let far = abs(translation) >= width * commitFraction
        let flick = abs(predictedEnd - translation) >= flickVelocity * 0.25 && (predictedEnd < 0) == (translation < 0)
        return far || flick
    }

    /// How far the page follows the finger.
    static func displayedOffset(translation: Double, hasNeighbor: Bool) -> Double {
        hasNeighbor ? translation : translation * edgeResistance
    }
}

/// A small least recently used store. Generic so the rules can be tested without images.
struct LRUStore<Value> {
    let capacity: Int
    private(set) var keys: [String] = []
    private var values: [String: Value] = [:]

    init(capacity: Int) {
        self.capacity = max(capacity, 0)
    }

    var count: Int { keys.count }

    mutating func value(for key: String) -> Value? {
        guard let value = values[key] else { return nil }
        touch(key)
        return value
    }

    mutating func set(_ value: Value, for key: String) {
        guard capacity > 0 else { return }
        values[key] = value
        touch(key)
        while keys.count > capacity {
            let oldest = keys.removeFirst()
            values[oldest] = nil
        }
    }

    mutating func removeAll() {
        keys.removeAll()
        values.removeAll()
    }

    private mutating func touch(_ key: String) {
        keys.removeAll { $0 == key }
        keys.append(key)
    }
}

/// Build 44: a picture of each recent page, shown at once when going back or switching tabs, so there is no blank
/// flash while the page draws. Memory only, never on disk, never for private tabs, and cleared by Burn It All,
/// Clear Browsing Data, Reset, and a low memory warning.
final class PageSnapshotCache {
    static let shared = PageSnapshotCache()
    /// Pages kept. Each picture is drawn at half the screen's scale, so the cache stays small.
    static let capacity = 12

    private var entries = LRUStore<UIImage>(capacity: PageSnapshotCache.capacity)
    private var memoryObserver: NSObjectProtocol?

    private init() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.removeAll()
        }
    }

    static func key(for url: URL?) -> String? {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url.absoluteString
    }

    func image(for url: URL?) -> UIImage? {
        guard let key = Self.key(for: url) else { return nil }
        return entries.value(for: key)
    }

    func store(_ image: UIImage, for url: URL?, isPrivate: Bool) {
        guard !isPrivate, BrowsingPolish.snapshotsOn, let key = Self.key(for: url) else { return }
        entries.set(Self.shrunk(image), for: key)
    }

    /// Redraws the picture at 1x, a fraction of a full resolution screenshot's memory.
    static func shrunk(_ image: UIImage) -> UIImage {
        guard image.scale > 1 else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    func removeAll() {
        entries.removeAll()
    }

    var count: Int { entries.count }
}
