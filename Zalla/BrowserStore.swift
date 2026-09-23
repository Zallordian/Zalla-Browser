import SwiftUI
import UIKit
import WebKit

struct SavedPage: Identifiable, Codable {
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
    @Published var tabs: [BrowserTab] = []
    @Published var selectedID: UUID?
    @Published private(set) var bookmarks: [SavedPage] = []
    @Published private(set) var history: [SavedPage] = []
    @Published var storageError: String?
    @Published var clearingData = false
    private let fileURL: URL

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
        } catch {
            storageError = "Your saved library could not be read. \(error.localizedDescription)"
        }
        addTab()
    }

    func addTab(isPrivate: Bool = false, url: URL? = nil) {
        let tab = BrowserTab(isPrivate: isPrivate)
        tab.onVisit = { [weak self] page in
            guard let self else { return }
            self.history.removeAll { $0.url == page.url }
            self.history.insert(page, at: 0)
            self.history = Array(self.history.prefix(500))
            self.save()
        }
        tabs.append(tab)
        selectedID = tab.id
        if let url { tab.load(url) }
    }

    func close(_ tab: BrowserTab) {
        tab.webView.stopLoading()
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty { addTab() }
        else if selectedID == tab.id { selectedID = tabs.last?.id }
    }

    func bookmark(_ tab: BrowserTab) {
        guard let url = tab.url, !bookmarks.contains(where: { $0.url == url }) else { return }
        bookmarks.append(SavedPage(title: tab.title, url: url))
        save()
    }

    func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    func clearBrowsingData() async {
        clearingData = true
        // Release pages before deletion so active pages cannot immediately recreate cookies.
        tabs.forEach { $0.webView.stopLoading() }
        tabs.removeAll()
        selectedID = nil
        clearHistory()
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        )
        addTab()
        clearingData = false
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

@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
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
    var onVisit: ((SavedPage) -> Void)?
    private var observations: [NSKeyValueObservation] = []

    init(isPrivate: Bool) {
        self.isPrivate = isPrivate
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isFindInteractionEnabled = true
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.refresh() },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.refresh() }
        ]
    }

    private func refresh() {
        title = webView.title ?? webView.url?.host ?? "New tab"
        url = webView.url
        progress = webView.estimatedProgress
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func load(_ url: URL) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        errorMessage = nil
        hasPage = true
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refresh()
        guard !isPrivate, let url, ["http", "https"].contains(url.scheme ?? "") else { return }
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

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        errorMessage = "This page stopped responding. Reload to continue."
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = url.scheme?.lowercased() ?? ""
        if ["http", "https", "about"].contains(scheme) {
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                webView.load(navigationAction.request)
            } else { decisionHandler(.allow) }
        } else {
            // App handoffs require a visible user action and explicit confirmation.
            if navigationAction.navigationType == .linkActivated,
               ["mailto", "tel", "sms"].contains(scheme) { externalURL = url }
            decisionHandler(.cancel)
        }
    }
    func findOnPage() {
        webView.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    private func hostController() -> UIViewController? {
        var responder: UIResponder? = webView
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return webView.window?.rootViewController
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
}
