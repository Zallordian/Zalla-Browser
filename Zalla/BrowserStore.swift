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
    @Published var tabs: [BrowserTab] = []
    @Published var selectedID: UUID?
    @Published private(set) var bookmarks: [SavedPage] = []
    @Published private(set) var history: [SavedPage] = []
    @Published var storageError: String?
    @Published var clearingData = false
    @Published var imageExport: ImageExportRequest?
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
        tab.onImageExport = { [weak self] request in
            self?.imageExport = request
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

    func clearHistory() {
        history.removeAll()
        save()
    }

    func clearBrowsingData() async {
        clearingData = true
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

    /// Destructive reset used by Settings. Bookmarks are kept by default.
    func resetApp(keepingBookmarks: Bool = true) async {
        clearingData = true
        tabs.forEach { $0.webView.stopLoading() }
        tabs.removeAll()
        selectedID = nil
        history.removeAll()
        if !keepingBookmarks {
            bookmarks.removeAll()
        }
        save()
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        )
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "appearance")
        defaults.removeObject(forKey: "searchEngine")
        defaults.removeObject(forKey: "themeID")
        defaults.removeObject(forKey: "appIconPreference")
        defaults.set(false, forKey: "hasCompletedOnboarding")
        if UIApplication.shared.supportsAlternateIcons {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UIApplication.shared.setAlternateIconName(nil) { _ in
                    continuation.resume()
                }
            }
        }
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

struct ImageExportRequest: Identifiable {
    let id = UUID()
    let sourceURL: URL
    let data: Data
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
    var onVisit: ((SavedPage) -> Void)?
    var onImageExport: ((ImageExportRequest) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private let scriptHandlerProxy = WeakScriptMessageHandler()

    init(isPrivate: Bool) {
        self.isPrivate = isPrivate
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        let controller = WKUserContentController()
        let script = WKUserScript(source: Self.imageLongPressScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        controller.addUserScript(script)
        configuration.userContentController = controller
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        scriptHandlerProxy.delegate = self
        controller.add(scriptHandlerProxy, name: "zallaImage")
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
