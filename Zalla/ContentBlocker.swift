import Foundation
import WebKit

extension Notification.Name {
    /// Posted on the main thread when the active rule lists or per-site choices change.
    static let zallaContentRulesChanged = Notification.Name("zallaContentRulesChanged")
}

/// Compiles the bundled and user rule lists with WKContentRuleListStore and hands them to tabs.
/// Compiling happens in WebKit's background queue; pages keep loading meanwhile and pick up the
/// lists on their next navigation once they are ready.
@MainActor
final class ContentBlocker: ObservableObject {
    enum Status: Equatable {
        case idle
        case compiling
        case ready
        case failed
    }

    private struct Source {
        let identifier: String
        let resource: String?
        let json: String?
    }

    static let shared = ContentBlocker()

    @Published private(set) var settings: ContentBlockingSettings
    @Published private(set) var status: Status = .idle

    private let manifest: BlocklistManifest?
    private var compiled: [String: WKContentRuleList] = [:]
    private var activeLists: [WKContentRuleList] = []
    private var currentIdentifiers: Set<String> = []
    private var rebuildTask: Task<Void, Never>?
    private var generation = 0
    /// Rule list identifiers last applied to each content controller. Popups share their
    /// opener's controller, so this is tracked per controller rather than per tab.
    private let applied = NSMapTable<WKUserContentController, NSArray>.weakToStrongObjects()

    private init() {
        settings = ContentBlockingSettings.load()
        manifest = BlocklistManifest.load()
        ZallaUnlock.shared.onChange = { [weak self] _ in
            self?.rebuild()
        }
    }

    var isUnlocked: Bool { ZallaUnlock.shared.isUnlocked }

    /// Starts the first compile. Safe to call more than once.
    func start() {
        guard rebuildTask == nil, activeLists.isEmpty else { return }
        rebuild()
    }

    // MARK: Tabs

    /// Rule lists for a page, or none when blocking is off for it.
    func ruleLists(for url: URL?) -> [WKContentRuleList] {
        settings.shouldBlock(url: url) ? activeLists : []
    }

    /// Adds or removes rule lists on a content controller for the page about to load.
    func apply(to controller: WKUserContentController, for url: URL?) {
        let lists = ruleLists(for: url)
        let identifiers = lists.compactMap { $0.identifier }
        if let current = applied.object(forKey: controller) as? [String], current == identifiers { return }
        controller.removeAllContentRuleLists()
        for list in lists {
            controller.add(list)
        }
        applied.setObject(identifiers as NSArray, forKey: controller)
    }

    func isBlockingOn(forHost host: String) -> Bool {
        !settings.isAllowed(host: host)
    }

    // MARK: Settings

    func update(_ change: (inout ContentBlockingSettings) -> Void) {
        var copy = settings
        change(&copy)
        guard copy != settings else { return }
        let old = settings
        settings = copy
        copy.save()
        if copy.needsRecompile(comparedTo: old) {
            rebuild()
        } else {
            NotificationCenter.default.post(name: .zallaContentRulesChanged, object: nil)
        }
    }

    func setBlocking(_ enabled: Bool, forHost host: String) {
        update { $0.setBlocking(enabled, forHost: host) }
    }

    /// Used by Reset the App: back to defaults, including user rules and the allow list.
    func resetSettings() {
        UserDefaults.standard.removeObject(forKey: ContentBlockingSettings.storageKey)
        update { $0 = ContentBlockingSettings() }
    }

    // MARK: Compiling

    func rebuild() {
        rebuildTask?.cancel()
        generation += 1
        let token = generation
        let sources = wantedSources()
        rebuildTask = Task { [weak self] in
            await self?.compile(sources, token: token)
        }
    }

    private func wantedSources() -> [Source] {
        var sources: [Source] = []
        for category in settings.activeCategories(unlocked: isUnlocked) {
            for part in manifest?.parts(for: category) ?? [] {
                sources.append(Source(
                    identifier: ContentBlockingSettings.identifier(for: part),
                    resource: part.resource,
                    json: nil
                ))
            }
        }
        let userLists = ContentBlockingSettings.split(settings.userRules(unlocked: isUnlocked))
        for (index, rules) in userLists.enumerated() {
            guard let json = ContentBlockingSettings.encoded(rules) else { continue }
            sources.append(Source(
                identifier: ContentBlockingSettings.userIdentifier(forJSON: json, index: index),
                resource: nil,
                json: json
            ))
        }
        return sources
    }

    private func compile(_ sources: [Source], token: Int) async {
        guard let store = WKContentRuleListStore.default() else {
            status = .failed
            return
        }
        status = .compiling
        var lists: [WKContentRuleList] = []
        var failed = false
        for source in sources {
            if Task.isCancelled { return }
            if let list = await ruleList(for: source, in: store) {
                lists.append(list)
            } else {
                failed = true
            }
        }
        guard token == generation, !Task.isCancelled else { return }
        activeLists = lists
        currentIdentifiers = Set(sources.map(\.identifier))
        status = failed ? .failed : .ready
        rebuildTask = nil
        NotificationCenter.default.post(name: .zallaContentRulesChanged, object: nil)
        await removeStaleLists(in: store)
    }

    /// Memory cache, then the on-disk store, then a fresh compile.
    private func ruleList(for source: Source, in store: WKContentRuleListStore) async -> WKContentRuleList? {
        if let cached = compiled[source.identifier] { return cached }
        if let stored = await Self.lookUp(source.identifier, in: store) {
            compiled[source.identifier] = stored
            return stored
        }
        guard let json = await Self.json(for: source) else { return nil }
        let fresh = await Self.compileList(json, identifier: source.identifier, in: store)
        if let fresh { compiled[source.identifier] = fresh }
        return fresh
    }

    private func removeStaleLists(in store: WKContentRuleListStore) async {
        var keep = currentIdentifiers
        for list in manifest?.lists ?? [] {
            keep.formUnion(list.parts.map(ContentBlockingSettings.identifier(for:)))
        }
        let stored = await Self.storedIdentifiers(in: store)
        for identifier in stored where identifier.hasPrefix(ContentBlockingSettings.identifierPrefix) && !keep.contains(identifier) {
            compiled[identifier] = nil
            await Self.remove(identifier, from: store)
        }
    }

    // MARK: WebKit store helpers

    private static func lookUp(_ identifier: String, in store: WKContentRuleListStore) async -> WKContentRuleList? {
        await withCheckedContinuation { (continuation: CheckedContinuation<WKContentRuleList?, Never>) in
            store.lookUpContentRuleList(forIdentifier: identifier) { list, _ in
                continuation.resume(returning: list)
            }
        }
    }

    private static func compileList(_ json: String, identifier: String, in store: WKContentRuleListStore) async -> WKContentRuleList? {
        await withCheckedContinuation { (continuation: CheckedContinuation<WKContentRuleList?, Never>) in
            store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { list, _ in
                continuation.resume(returning: list)
            }
        }
    }

    private static func storedIdentifiers(in store: WKContentRuleListStore) async -> [String] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            store.getAvailableContentRuleListIdentifiers { identifiers in
                continuation.resume(returning: identifiers ?? [])
            }
        }
    }

    private static func remove(_ identifier: String, from store: WKContentRuleListStore) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.removeContentRuleList(forIdentifier: identifier) { _ in
                continuation.resume()
            }
        }
    }

    /// Reads and inflates a bundled list off the main thread.
    private static func json(for source: Source) async -> String? {
        if let json = source.json { return json }
        guard let resource = source.resource,
              let url = Bundle.main.url(forResource: resource, withExtension: "deflate") else { return nil }
        return await Task.detached(priority: .utility) { () -> String? in
            guard let packed = try? Data(contentsOf: url),
                  let inflated = try? (packed as NSData).decompressed(using: .zlib) else { return nil }
            return String(data: inflated as Data, encoding: .utf8)
        }.value
    }
}
