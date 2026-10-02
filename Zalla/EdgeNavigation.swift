import UIKit
import WebKit

/// Swipe in from the left edge to go back, from the right edge to go forward.
/// This is Zalla's own edge pan on the web view. WebKit's built in gesture is switched off so the two never
/// both fire, and so the swipe works the same for every tab, new tab, and popup.
final class EdgeNavigationRecognizer: UIScreenEdgePanGestureRecognizer, UIGestureRecognizerDelegate {
    private weak var webView: WKWebView?
    /// The tab that owns the web view. It knows about the new tab page, which counts as a history entry.
    private weak var tab: BrowserTab?
    private let side: EdgeSwipe.Side
    private var cue: EdgeSwipeCue?
    private var armed = false

    init(webView: WKWebView, tab: BrowserTab?, side: EdgeSwipe.Side) {
        self.webView = webView
        self.tab = tab
        self.side = side
        super.init(target: nil, action: nil)
        edges = side == .left ? .left : .right
        addTarget(self, action: #selector(handle))
        delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let webView else { return false }
        return EdgeSwipe.canBegin(
            side: side,
            enabled: SwipeNavigation.isEnabled,
            canGoBack: tab?.canNavigateBack ?? webView.canGoBack,
            canGoForward: tab?.canNavigateForward ?? webView.canGoForward
        )
    }

    /// Lets the page keep scrolling and the fan, toolbar, and tab gestures keep their own touches.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    @objc private func handle() {
        guard let webView else { return }
        let x = Double(translation(in: webView).x)
        switch state {
        case .began:
            armed = false
            cue = EdgeSwipeCue(side: side, host: webView)
            cue?.update(progress: 0, y: location(in: webView).y)
        case .changed:
            let progress = EdgeSwipe.progress(translation: x, side: side)
            cue?.update(progress: progress, y: location(in: webView).y)
            if progress >= 1, !armed {
                armed = true
                UISelectionFeedbackGenerator().selectionChanged()
            }
        case .ended:
            let commit = EdgeSwipe.shouldCommit(translation: x, velocity: Double(velocity(in: webView).x), side: side)
            if commit {
                if let tab {
                    if side == .left { tab.goBack() } else { tab.goForward() }
                } else {
                    if side == .left { webView.goBack() } else { webView.goForward() }
                }
            }
            cue?.finish(committed: commit)
            cue = nil
        case .cancelled, .failed:
            cue?.finish(committed: false)
            cue = nil
        default:
            break
        }
    }
}

/// The small arrow that follows the finger while an edge swipe is in progress.
private final class EdgeSwipeCue: UIView {
    private let side: EdgeSwipe.Side
    private let size: CGFloat = 44

    init(side: EdgeSwipe.Side, host: UIView) {
        self.side = side
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        isUserInteractionEnabled = false
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        layer.cornerRadius = 22
        let icon = UIImageView(image: UIImage(
            systemName: side == .left ? "chevron.left" : "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        ))
        icon.tintColor = .white
        icon.contentMode = .center
        icon.frame = bounds
        addSubview(icon)
        alpha = 0
        host.addSubview(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func update(progress: Double, y: CGFloat) {
        guard let host = superview else { return }
        let travel = CGFloat(progress) * (size / 2 + 40)
        let x = side == .left ? -size / 2 + travel : host.bounds.width + size / 2 - travel
        center = CGPoint(x: x, y: min(max(y, 80), host.bounds.height - 80))
        alpha = CGFloat(progress)
        let scale = 0.7 + 0.3 * CGFloat(progress)
        transform = CGAffineTransform(scaleX: scale, y: scale)
        host.bringSubviewToFront(self)
    }

    func finish(committed: Bool) {
        UIView.animate(withDuration: committed ? 0.18 : 0.12, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: committed ? 1.2 : 0.7, y: committed ? 1.2 : 0.7)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}

enum EdgeNavigation {
    /// Adds the edge swipes to a web view once, and turns them on or off. Safe to call again for the same web view.
    @MainActor
    static func install(on webView: WKWebView, tab: BrowserTab? = nil, enabled: Bool) {
        // WebKit's own gesture stays off: Zalla's takes over so the swipe works in every layout.
        webView.allowsBackForwardNavigationGestures = false
        var ours = webView.gestureRecognizers?.compactMap { $0 as? EdgeNavigationRecognizer } ?? []
        if ours.isEmpty {
            for side in [EdgeSwipe.Side.left, EdgeSwipe.Side.right] {
                let recognizer = EdgeNavigationRecognizer(webView: webView, tab: tab, side: side)
                webView.addGestureRecognizer(recognizer)
                ours.append(recognizer)
            }
        }
        for recognizer in ours { recognizer.isEnabled = enabled }
    }
}
