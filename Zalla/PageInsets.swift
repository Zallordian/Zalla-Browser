import UIKit
import WebKit

/// Build 54: where the page starts and ends under Zalla's chrome.
///
/// The bug this fixes: on a site that asks for `viewport-fit=cover` (bambulab.com is one), WebKit switches the web
/// view's scroll view to `contentInsetAdjustmentBehavior = .never`, so the scroll view stops adding the status bar
/// and home indicator to its insets. Zalla used to copy `adjustedContentInset` into `obscuredContentInsets`, so on those
/// sites the obscured top was only the top bar height (zero with the bar at the bottom). WebKit then laid the site's
/// fixed header out at the very top of the screen, under the clock, where taps go to the status bar.
///
/// Now the insets are worked out here from the web view's own safe area plus the chrome over it, never read back from
/// the scroll view, so every site and every layout gets the same answer. With the top fully reported as obscured,
/// WebKit puts `position: fixed; top: 0` just below the status bar and top bar (like Safari) and reports
/// `env(safe-area-inset-top)` as 0, so a site that pads for the notch does not get the gap twice. The page itself
/// still scrolls under the transparent status bar and floating chrome.
enum PageInsets {
    /// Total insets for the page: the part of the device safe area the web view frame overlaps, plus the chrome
    /// heights drawn over the page inside that safe area. Negative inputs count as zero.
    static func resolve(chrome: UIEdgeInsets, safeArea: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: max(chrome.top, 0) + max(safeArea.top, 0),
            left: max(chrome.left, 0) + max(safeArea.left, 0),
            bottom: max(chrome.bottom, 0) + max(safeArea.bottom, 0),
            right: max(chrome.right, 0) + max(safeArea.right, 0)
        )
    }

    /// The part of the device safe area the web view frame overlaps. The frame skips the top safe area (it starts
    /// below the clock) while a status bar strip is painted, and always on systems without `obscuredContentInsets`.
    static func webViewSafeArea(device: UIEdgeInsets, frameStartsBelowStatusBar: Bool) -> UIEdgeInsets {
        var insets = device
        if frameStartsBelowStatusBar { insets.top = 0 }
        return insets
    }

    /// Whether the page frame should start below the status bar. True while a strip is painted there, and on
    /// systems where WebKit has no public way to keep a site's fixed header clear of the clock (before iOS 26).
    static func frameStartsBelowStatusBar(stripPainted: Bool, obscuredInsetsSupported: Bool) -> Bool {
        stripPainted || !obscuredInsetsSupported
    }

    /// Applies the insets to a web view. On iOS 26 and later Zalla owns the insets outright: the automatic
    /// adjustment is turned off (so WebKit cannot flip it per site) and the full insets go to both the scroll view and
    /// `obscuredContentInsets`. Earlier systems keep the automatic adjustment, which already keeps fixed headers clear
    /// of the safe area for ordinary sites, and only the chrome heights are added.
    @MainActor
    static func apply(chrome: UIEdgeInsets, to webView: WKWebView) {
        let scrollView = webView.scrollView
        // While the pull to refresh spinner is out, UIKit owns the top inset.
        if scrollView.refreshControl?.isRefreshing == true { return }
        let target: UIEdgeInsets
        if ObscuredInsets.isSupported {
            if scrollView.contentInsetAdjustmentBehavior != .never {
                scrollView.contentInsetAdjustmentBehavior = .never
            }
            if scrollView.automaticallyAdjustsScrollIndicatorInsets {
                scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            target = resolve(chrome: chrome, safeArea: webView.safeAreaInsets)
        } else {
            target = chrome
        }
        if scrollView.contentInset != target {
            let wasAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 1
            scrollView.contentInset = target
            scrollView.verticalScrollIndicatorInsets = target
            if wasAtTop {
                // Keep the top of the page just below the top bar instead of hidden under it.
                scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
            }
        }
        if ObscuredInsets.isSupported {
            ObscuredInsets.apply(target, to: webView)
        }
    }
}

/// The web view every tab uses. It remembers the chrome insets so it can redo the page insets itself whenever its
/// safe area changes (first layout, rotation, the keyboard), which SwiftUI does not always report.
final class ZallaWebView: WKWebView {
    var chromeInsets: UIEdgeInsets = .zero {
        didSet {
            if chromeInsets != oldValue { PageInsets.apply(chrome: chromeInsets, to: self) }
        }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        PageInsets.apply(chrome: chromeInsets, to: self)
    }
}
