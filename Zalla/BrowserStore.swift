import SwiftUI
import UIKit
import WebKit

struct SavedPage: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: URL
    var visitedAt = Date()
}

private struct Library: Codable {
    var bookmarks: [SavedPage] = []
    var history: [SavedPage] = []
}

@MainActor
final class BrowserStore: ObservableObject {
    @Published var tabs: [BrowserTab] = [] {
        didSet { scheduleSessionSave() }
    }
    @Published var selectedID: UUID? {
        didSet {
            selected?.restoreIfNeeded()
            scheduleSessionSave()
        }
    }
    @Published private(set) var bookmarks: [SavedPage] = []
    @Published private(set) var history: [SavedPage] = []
    @Published private(set) var downloads: [DownloadRecord] = []
    @Published var storageError: String?
    @Published var clearingData = false
    @Published var imageExport: ImageExportRequest?
    private let fileURL: URL
    private var activeDownloadDelegates: [UUID: TabDownloadSession] = [:]
    private var sessionSaveTask: Task<Void, Never>?
    /// Off while restoring or clearing, so half-built tab lists never overwrite the saved session.
    private var sessionSavingEnabled = false

    var selected: BrowserTab? { tabs.first { $0.id == selectedID } }

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zalla", isDirectory: true)
        fileURL = directory.appendingPathComponent("library.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var excluded = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try excluded.setResourceValues(values)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: fileURL))
                bookmarks = library.bookmarks
                history = library.history
            }
            downloads = DownloadsStore.load()
        } catch {
            storageError = "Your saved library could not be read. \(error.localizedDescription)"
        }
        // Seed home shortcuts on first launch if missing.
        if UserDefaults.standard.data(forKey: HomeShortcuts.storageKey) == nil {
            HomeShortcuts.save(HomeShortcuts.defaults)
        }
        if !restoreSession() {
            addTab()
        }
        sessionSavingEnabled = true
    }

    @discardableResult
    func addTab(isPrivate: Bool = false, url: URL? = nil) -> BrowserTab {
        let tab = BrowserTab(isPrivate: isPrivate)
        configure(tab)
        tabs.append(tab)
        selectedID = tab.id
        if let url { tab.load(url) }
        return tab
    }

    private func configure(_ tab: BrowserTab) {
        tab.onVisit = { [weak self] page in
            guard let self else { return }
            self.history.removeAll { $0.url == page.url }
            self.history.insert(page, at: 0)
            self.history = Array(self.history.prefix(500))
            self.save()
        }
        tab.onImageExport = { [weak self] request in
            self?.imageExport = request
        }
        tab.onDownloadDecision = { [weak self] tab, download, response, sourceURL in
            self?.beginDownload(tab: tab, download: download, response: response, sourceURL: sourceURL)
        }
        tab.onSessionChange = { [weak self] in
            self?.scheduleSessionSave()
        }
        tab.onOpenWindow = { [weak self] opener, configuration in
            self?.openChildTab(from: opener, configuration: configuration)
        }
        tab.onCloseWindow = { [weak self] tab in
            self?.closeScriptWindow(tab)
        }
    }

    // MARK: - Popups and new windows

    /// window.open and target=_blank: a child tab built from WebKit's configuration, so the opener
    /// relationship (OAuth, payment popups) keeps working. Opens next to its opener and takes focus.
    private func openChildTab(from opener: BrowserTab, configuration: WKWebViewConfiguration) -> BrowserTab {
        let child = BrowserTab(isPrivate: opener.isPrivate, configuration: configuration)
        configure(child)
        child.openerID = opener.id
        child.hasPage = true
        if let index = tabs.firstIndex(where: { $0.id == opener.id }) {
            tabs.insert(child, at: index + 1)
        } else {
            tabs.append(child)
        }
        selectTab(child)
        return child
    }

    /// window.close from a page: close that tab and go back to the page that opened it.
    private func closeScriptWindow(_ tab: BrowserTab) {
        guard tabs.contains(where: { $0.id == tab.id }) else { return }
        let wasSelected = selectedID == tab.id
        let openerID = tab.openerID
        close(tab)
        if wasSelected, let openerID, let opener = tabs.first(where: { $0.id == openerID }) {
            selectedID = opener.id
        }
    }

    // MARK: - Session restore

    /// Restores normal tabs from the last run. Only the selected tab loads now; the rest load when opened.
    private func restoreSession() -> Bool {
        guard let snapshot = TabSession.load(), !snapshot.isEmpty else { return false }
        var restored: [BrowserTab] = []
        for entry in snapshot.tabs {
            let tab = BrowserTab(isPrivate: false)
            configure(tab)
            tab.prepareRestore(from: entry)
            restored.append(tab)
        }
        tabs = restored
        let index = snapshot.selectedIndex ?? (restored.count - 1)
        selectedID = restored.indices.contains(index) ? restored[index].id : restored.last?.id
        return true
    }

    private func scheduleSessionSave() {
        guard sessionSavingEnabled else { return }
        sessionSaveTask?.cancel()
        sessionSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            self?.saveSession()
        }
    }

    /// Writes open normal tabs now. Called on changes (debounced) and when the app leaves the foreground.
    func saveSession() {
        guard sessionSavingEnabled else { return }
        sessionSaveTask?.cancel()
        sessionSaveTask = nil
        let snapshot = TabSession.snapshot(from: tabs.map { $0.sessionSource(isSelected: $0.id == selectedID) })
        do {
            try TabSession.save(snapshot)
        } catch {
            // Session restore is best effort; never interrupt browsing for it.
        }
    }

    private func clearSavedSession() {
        sessionSaveTask?.cancel()
        sessionSaveTask = nil
        TabSession.clear()
    }

    func close(_ tab: BrowserTab) {
        tab.capturePreview()
        tab.webView.stopLoading()
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty { addTab() }
        else if selectedID == tab.id { selectedID = tabs.last?.id }
    }

    func closeAllTabs() {
        let snapshot = tabs
        for tab in snapshot {
            tab.capturePreview()
            tab.webView.stopLoading()
        }
        tabs.removeAll()
        selectedID = nil
        addTab()
    }

    func selectTab(_ tab: BrowserTab) {
        if let current = selected, current.id != tab.id {
            current.capturePreview()
        }
        selectedID = tab.id
    }

    func bookmark(_ tab: BrowserTab) {
        guard let url = tab.url, !bookmarks.contains(where: { $0.url == url }) else { return }
        bookmarks.append(SavedPage(title: tab.title, url: url))
        save()
    }

    @discardableResult
    func importBookmarks(_ pages: [SavedPage]) -> Int {
        var added = 0
        for page in pages {
            if bookmarks.contains(where: { $0.url == page.url }) { continue }
            bookmarks.append(page)
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save()
    }

    func renameBookmark(id: UUID, title: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        bookmarks[index].title = cleaned
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    func clearBrowsingData() async {
        clearingData = true
        sessionSavingEnabled = false
        clearSavedSession()
        MediaPermissionSession.memory.removeAll()
        tabs.forEach { $0.webView.stopLoading() }
        tabs.removeAll()
        selectedID = nil
        clearHistory()
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        )
        addTab()
        sessionSavingEnabled = true
        clearingData = false
    }

    /// Destructive reset used by Settings. Bookmarks are kept by default.
    func resetApp(keepingBookmarks: Bool = true) async {
        clearingData = true
        sessionSavingEnabled = false
        clearSavedSession()
        MediaPermissionSession.memory.removeAll()
        tabs.forEach { $0.webView.stopLoading() }
        tabs.removeAll()
        selectedID = nil
        history.removeAll()
        if !keepingBookmarks {
            bookmarks.removeAll()
        }
        clearAllDownloads()
        save()
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        )
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "appearance")
        defaults.removeObject(forKey: "searchEngine")
        defaults.removeObject(forKey: "themeID")
        defaults.removeObject(forKey: "appIconPreference")
        defaults.removeObject(forKey: ToolbarStyle.storageKey)
        defaults.removeObject(forKey: AddressBarPlacement.storageKey)
        defaults.removeObject(forKey: "useCustomAccent")
        defaults.removeObject(forKey: "customAccentHex")
        defaults.removeObject(forKey: "customAccentGradient")
        defaults.removeObject(forKey: HomeWelcomeMode.storageKey)
        defaults.removeObject(forKey: HomeWelcomeMode.userNameKey)
        defaults.removeObject(forKey: ChromeModeTips.compactSeenKey)
        defaults.removeObject(forKey: ChromeModeTips.topBarSeenKey)
        defaults.removeObject(forKey: ChromeModeTips.holdRevealSeenKey)
        defaults.removeObject(forKey: ChromeModeTips.quickActionSeenKey)
        defaults.set(false, forKey: "hasCompletedOnboarding")
        HomeShortcuts.resetToDefaults()
        if UIApplication.shared.supportsAlternateIcons {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UIApplication.shared.setAlternateIconName(nil) { _ in
                    continuation.resume()
                }
            }
        }
        addTab()
        sessionSavingEnabled = true
        clearingData = false
    }

    // MARK: - Downloads

    private func beginDownload(tab: BrowserTab, download: WKDownload, response: URLResponse, sourceURL: URL) {
        let filename = DownloadsStore.suggestedFilename(from: response, sourceURL: sourceURL)
        let destination = DownloadsStore.uniqueDestination(for: filename)
        let record = DownloadRecord(
            filename: filename,
            sourceURL: sourceURL,
            localRelativePath: destination.relative,
            byteCount: response.expectedContentLength > 0 ? response.expectedContentLength : nil,
            state: .downloading,
            isPrivate: tab.isPrivate
        )
        downloads.insert(record, at: 0)
        persistDownloads()

        let session = TabDownloadSession(
            recordID: record.id,
            destinationURL: destination.url,
            onUpdate: { [weak self] id, state, bytes, errorMessage in
                self?.updateDownload(id: id, state: state, byteCount: bytes, errorMessage: errorMessage)
            },
            onFinish: { [weak self] id in
                self?.activeDownloadDelegates[id] = nil
            }
        )
        activeDownloadDelegates[record.id] = session
        download.delegate = session
    }

    private func updateDownload(id: UUID, state: DownloadState, byteCount: Int64?, errorMessage: String?) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = state
        if let byteCount { downloads[index].byteCount = byteCount }
        downloads[index].errorMessage = errorMessage
        persistDownloads()
    }

    func removeDownload(_ record: DownloadRecord) {
        if let url = record.localFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        downloads.removeAll { $0.id == record.id }
        persistDownloads()
    }

    func clearAllDownloads() {
        for record in downloads {
            if let url = record.localFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        downloads.removeAll()
        persistDownloads()
    }

    private func persistDownloads() {
        do {
            try DownloadsStore.save(downloads)
        } catch {
            storageError = "Your downloads list could not be saved. \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(Library(bookmarks: bookmarks, history: history))
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            storageError = "Your changes could not be saved. \(error.localizedDescription)"
        }
    }
}

struct ImageExportRequest: Identifiable {
    let id = UUID()
    let sourceURL: URL
    let data: Data
}

/// Bridges WKDownloadDelegate callbacks into BrowserStore without retaining the tab forever.
final class TabDownloadSession: NSObject, WKDownloadDelegate {
    let recordID: UUID
    let destinationURL: URL
    let onUpdate: (UUID, DownloadState, Int64?, String?) -> Void
    let onFinish: (UUID) -> Void

    init(
        recordID: UUID,
        destinationURL: URL,
        onUpdate: @escaping (UUID, DownloadState, Int64?, String?) -> Void,
        onFinish: @escaping (UUID) -> Void
    ) {
        self.recordID = recordID
        self.destinationURL = destinationURL
        self.onUpdate = onUpdate
        self.onFinish = onFinish
    }

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        completionHandler(destinationURL)
    }

    func downloadDidFinish(_ download: WKDownload) {
        var bytes: Int64?
        if let values = try? destinationURL.resourceValues(forKeys: [.fileSizeKey]),
           let size = values.fileSize {
            bytes = Int64(size)
        }
        let id = recordID
        let update = onUpdate
        let finish = onFinish
        Task { @MainActor in
            update(id, .completed, bytes, nil)
            finish(id)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let message = error.localizedDescription
        let id = recordID
        let update = onUpdate
        let finish = onFinish
        Task { @MainActor in
            update(id, .failed, nil, message)
            finish(id)
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler? = nil) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let id = UUID()
    let isPrivate: Bool
    let webView: WKWebView
    @Published var title = "New tab"
    @Published var url: URL?
    @Published var progress = 0.0
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var hasPage = false
    @Published var errorMessage: String?
    @Published var externalURL: URL?
    @Published var previewImage: UIImage?
    @Published var isReaderActive = false
    @Published var readerAvailable = false
    @Published var hasOnlySecureContent = true
    var onVisit: ((SavedPage) -> Void)?
    var onImageExport: ((ImageExportRequest) -> Void)?
    var onDownloadDecision: ((BrowserTab, WKDownload, URLResponse, URL) -> Void)?
    /// Fires when something worth saving in the tab session changes (committed URL or title).
    var onSessionChange: (() -> Void)?
    /// Creates a child tab for window.open / target=_blank using WebKit's configuration.
    var onOpenWindow: ((BrowserTab, WKWebViewConfiguration) -> BrowserTab?)?
    /// Called when a page runs window.close on this tab.
    var onCloseWindow: ((BrowserTab) -> Void)?
    /// The tab that opened this one with window.open or target=_blank, if any.
    var openerID: UUID?
    /// Saved state waiting for the tab to be opened after a cold launch.
    private var pendingRestore: TabSessionEntry?
    private var observations: [NSKeyValueObservation] = []
    private let scriptHandlerProxy = WeakScriptMessageHandler()
    private var pendingDownloadResponse: URLResponse?
    private var pendingDownloadURL: URL?
    private var readerOriginalURL: URL?
    private var lastSnapshotAt: Date?

    /// Pass `configuration` only for popups: WebKit requires the child web view to use the exact
    /// configuration it provides. That copy already shares the opener's data store, user script,
    /// and message handler, so none of them are added again (a duplicate handler name would crash).
    init(isPrivate: Bool, configuration popupConfiguration: WKWebViewConfiguration? = nil) {
        self.isPrivate = isPrivate
        let configuration: WKWebViewConfiguration
        var newController: WKUserContentController?
        if let popupConfiguration {
            configuration = popupConfiguration
        } else {
            configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
            // Play video in the page (needed for camera previews and calls) instead of forcing full screen.
            configuration.allowsInlineMediaPlayback = true
            let controller = WKUserContentController()
            let script = WKUserScript(source: Self.imageLongPressScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            controller.addUserScript(script)
            configuration.userContentController = controller
            newController = controller
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        if let newController {
            scriptHandlerProxy.delegate = self
            newController.add(scriptHandlerProxy, name: "zallaImage")
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isFindInteractionEnabled = true
        webView.allowsBackForwardNavigationGestures = true
        // Avoid black flash behind page chrome and during empty/transient loads.
        webView.backgroundColor = .systemBackground
        webView.isOpaque = true
        webView.underPageBackgroundColor = .systemBackground
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.hasOnlySecureContent, options: [.new]) { [weak self] _, _ in self?.refresh() }
        ]
    }

    private static let imageLongPressScript = """
    (function() {
      if (window.__zallaImageHook) return;
      window.__zallaImageHook = true;
      var timer = null;
      function send(src) {
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.zallaImage) {
            window.webkit.messageHandlers.zallaImage.postMessage({ src: src });
          }
        } catch (e) {}
      }
      document.addEventListener('touchstart', function(e) {
        var t = e.target;
        if (!t || t.tagName !== 'IMG' || !t.src) return;
        timer = setTimeout(function() { send(t.src); }, 480);
      }, { passive: true });
      document.addEventListener('touchend', function() { if (timer) clearTimeout(timer); }, { passive: true });
      document.addEventListener('touchmove', function() { if (timer) clearTimeout(timer); }, { passive: true });
      document.addEventListener('contextmenu', function(e) {
        var t = e.target;
        if (t && t.tagName === 'IMG' && t.src) {
          send(t.src);
        }
      });
    })();
    """

    private func refresh() {
        if !isReaderActive {
            title = webView.title ?? webView.url?.host ?? "New tab"
            url = webView.url
        }
        progress = webView.estimatedProgress
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        hasOnlySecureContent = webView.hasOnlySecureContent
    }

    func load(_ url: URL) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        errorMessage = nil
        isReaderActive = false
        readerOriginalURL = nil
        hasPage = true
        webView.load(URLRequest(url: url))
    }

    /// Shows a restored tab's title and URL without loading it yet.
    func prepareRestore(from entry: TabSessionEntry) {
        guard TabSession.isRestorable(entry.url) else { return }
        pendingRestore = entry
        title = entry.title
        url = entry.url
        hasPage = true
    }

    /// Loads a restored tab the first time it is shown: back/forward state when available, else the URL.
    func restoreIfNeeded() {
        guard let entry = pendingRestore else { return }
        pendingRestore = nil
        errorMessage = nil
        if let state = entry.interactionState {
            webView.interactionState = state
            if webView.backForwardList.currentItem != nil { return }
        }
        load(entry.url)
    }

    /// Plain description of this tab for the session snapshot. Private tabs are filtered out later.
    func sessionSource(isSelected: Bool) -> TabSession.Source {
        if let pendingRestore {
            return TabSession.Source(
                isPrivate: isPrivate,
                url: pendingRestore.url,
                title: pendingRestore.title,
                isSelected: isSelected,
                interactionState: pendingRestore.interactionState
            )
        }
        // Reader pages are local HTML, so save only the original URL for them.
        let state = (isPrivate || isReaderActive) ? nil : webView.interactionState as? Data
        return TabSession.Source(
            isPrivate: isPrivate,
            url: hasPage ? url : nil,
            title: title,
            isSelected: isSelected,
            interactionState: state
        )
    }

    func backHistoryItems(limit: Int = 5) -> [HistoryListItem] {
        let list = webView.backForwardList.backList.reversed().prefix(limit)
        let mapped = list.map { item -> (title: String, url: URL) in
            let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (title, item.url)
        }
        return HistoryListHelper.limited(Array(mapped), limit: limit)
    }

    func forwardHistoryItems(limit: Int = 5) -> [HistoryListItem] {
        let list = webView.backForwardList.forwardList.prefix(limit)
        let mapped = list.map { item -> (title: String, url: URL) in
            let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (title, item.url)
        }
        return HistoryListHelper.limited(Array(mapped), limit: limit)
    }

    func goToBackForwardItem(_ item: WKBackForwardListItem) {
        isReaderActive = false
        readerOriginalURL = nil
        webView.go(to: item)
    }

    func goToHistoryListItem(_ item: HistoryListItem, direction: HoldRevealKind) {
        let source: [WKBackForwardListItem]
        switch direction {
        case .back:
            source = Array(webView.backForwardList.backList.reversed().prefix(5))
        case .forward:
            source = Array(webView.backForwardList.forwardList.prefix(5))
        }
        let index = item.id - 1
        guard source.indices.contains(index) else { return }
        goToBackForwardItem(source[index])
    }

    func capturePreview() {
        guard hasPage, !isLoading else { return }
        if let lastSnapshotAt, Date().timeIntervalSince(lastSnapshotAt) < 1.5 { return }
        lastSnapshotAt = Date()
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            Task { @MainActor in
                self?.previewImage = image
            }
        }
    }

    func enterReaderMode(dark: Bool) {
        guard hasPage, !isReaderActive else { return }
        webView.evaluateJavaScript(ReaderMode.extractScript) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if error != nil {
                    self.errorMessage = ReaderMode.ExtractFailure.scriptError.userMessage
                    return
                }
                switch ReaderMode.parseResult(result) {
                case .failure(let failure):
                    self.errorMessage = failure.userMessage
                case .success(let article):
                    self.readerOriginalURL = self.webView.url
                    let html = ReaderMode.buildHTML(
                        title: article.title,
                        byline: article.byline,
                        site: article.site,
                        paragraphs: article.paragraphs,
                        dark: dark
                    )
                    self.isReaderActive = true
                    self.title = article.title
                    self.webView.loadHTMLString(html, baseURL: self.readerOriginalURL)
                }
            }
        }
    }

    func exitReaderMode() {
        guard isReaderActive else { return }
        isReaderActive = false
        if let original = readerOriginalURL {
            readerOriginalURL = nil
            webView.load(URLRequest(url: original))
        } else {
            readerOriginalURL = nil
            webView.goBack()
        }
    }

    func toggleReaderMode(dark: Bool) {
        if isReaderActive {
            exitReaderMode()
        } else {
            enterReaderMode(dark: dark)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "zallaImage",
              let body = message.body as? [String: Any],
              let src = body["src"] as? String,
              let imageURL = URL(string: src) else { return }
        Task { await prepareImageExport(from: imageURL) }
    }

    private func prepareImageExport(from imageURL: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            onImageExport?(ImageExportRequest(sourceURL: imageURL, data: data))
        } catch {
            errorMessage = "Could not load that image for export."
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorMessage = nil
        if !isReaderActive {
            readerAvailable = false
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refresh()
        if !isReaderActive {
            readerAvailable = hasPage
            capturePreview()
        }
        if !isPrivate { onSessionChange?() }
        guard !isPrivate, !isReaderActive, let url, ["http", "https"].contains(url.scheme ?? "") else { return }
        onVisit?(SavedPage(title: title, url: url))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        show(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        show(error)
    }

    private func show(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        errorMessage = error.localizedDescription
    }

    func dismissError() {
        errorMessage = nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        errorMessage = "This page stopped responding. Reload to continue."
        let restoreURL = url ?? webView.url ?? webView.backForwardList.currentItem?.url
        if let restoreURL, ["http", "https"].contains(restoreURL.scheme?.lowercased() ?? "") {
            webView.load(URLRequest(url: restoreURL))
        } else {
            webView.reload()
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "blob" || scheme == "data" {
            // JS-triggered blob/data downloads become WKDownload via the action path.
            pendingDownloadURL = url
            decisionHandler(.download)
            return
        }
        if ["http", "https", "about"].contains(scheme) {
            if navigationAction.targetFrame == nil, onOpenWindow == nil {
                decisionHandler(.cancel)
                webView.load(navigationAction.request)
            } else {
                // New-window actions are allowed so WebKit asks createWebViewWith for a child tab.
                decisionHandler(.allow)
            }
        } else {
            if navigationAction.navigationType == .linkActivated,
               ["mailto", "tel", "sms"].contains(scheme) { externalURL = url }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let response = navigationResponse.response
        if navigationResponse.canShowMIMEType == false || DownloadsStore.isLikelyDownload(response: response) {
            pendingDownloadResponse = response
            pendingDownloadURL = response.url ?? url
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        let response = pendingDownloadResponse ?? navigationResponse.response
        let source = pendingDownloadURL ?? response.url ?? URL(string: "about:blank")!
        pendingDownloadResponse = nil
        pendingDownloadURL = nil
        onDownloadDecision?(self, download, response, source)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        // Covers blob: and JS-triggered downloads that become WKDownload via the action path.
        let source = navigationAction.request.url
            ?? pendingDownloadURL
            ?? URL(string: "blob:download")!
        let response = pendingDownloadResponse
            ?? URLResponse(url: source, mimeType: "application/octet-stream", expectedContentLength: -1, textEncodingName: nil)
        pendingDownloadResponse = nil
        pendingDownloadURL = nil
        onDownloadDecision?(self, download, response, source)
    }

    func findOnPage() {
        webView.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    private func hostController() -> UIViewController? {
        var responder: UIResponder? = webView
        var found: UIViewController?
        while let current = responder {
            if let controller = current as? UIViewController { found = controller; break }
            responder = current.next
        }
        guard var host = found ?? webView.window?.rootViewController else { return nil }
        // Present above any sheet that is already showing, or the alert would silently fail.
        while let presented = host.presentedViewController, !presented.isBeingDismissed {
            host = presented
        }
        return host
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let child = onOpenWindow?(self, configuration) {
            return child.webView
        }
        // No tab host: fall back to opening the link in this tab.
        if let url = navigationAction.request.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {
        onCloseWindow?(self)
    }

    /// Camera and microphone requests: ask per site with Allow / Don't Allow, and remember the
    /// answer for this app session only. iOS shows its own one-time system prompt after Allow.
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let kind: MediaCaptureKind
        switch type {
        case .camera: kind = .camera
        case .microphone: kind = .microphone
        case .cameraAndMicrophone: kind = .cameraAndMicrophone
        @unknown default: kind = .cameraAndMicrophone
        }
        let site = MediaCapturePrompt.siteLabel(scheme: origin.protocol, host: origin.host, port: origin.port)
        let privateTab = isPrivate
        if let remembered = MediaPermissionSession.memory.decision(site: site, kind: kind, isPrivate: privateTab) {
            decisionHandler(remembered ? .grant : .deny)
            return
        }
        guard let host = hostController() else { decisionHandler(.deny); return }
        let alert = UIAlertController(
            title: MediaCapturePrompt.title(site: site, kind: kind),
            message: MediaCapturePrompt.message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: MediaCapturePrompt.denyTitle, style: .cancel) { _ in
            MediaPermissionSession.memory.remember(false, site: site, kind: kind, isPrivate: privateTab)
            decisionHandler(.deny)
        })
        alert.addAction(UIAlertAction(title: MediaCapturePrompt.allowTitle, style: .default) { _ in
            MediaPermissionSession.memory.remember(true, site: site, kind: kind, isPrivate: privateTab)
            decisionHandler(.grant)
        })
        host.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard let host = hostController() else { completionHandler(); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        host.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard let host = hostController() else { completionHandler(false); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        host.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard let host = hostController() else { completionHandler(nil); return }
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        host.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
                 completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        if let link = elementInfo.linkURL {
            let ext = link.pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "gif", "webp", "heic", "tif", "tiff", "bmp"].contains(ext) {
                completionHandler(UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                    let export = UIAction(title: "Export image as...", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                        Task { await self?.prepareImageExport(from: link) }
                    }
                    return UIMenu(title: "", children: [export])
                })
                return
            }
        }
        completionHandler(nil)
    }
}
