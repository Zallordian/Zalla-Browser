import Foundation
import WebKit

/// Build 39: press and hold on a page image to export it. The page script only reports a hold that stayed put, and
/// the app checks the report again before showing the Export image sheet.
enum ImageHold {
    static let messageName = "zallaImage"
    /// How long the finger has to stay down, in milliseconds.
    static let minimumHoldMs: Double = 500
    /// How far the finger may wander, in points, before the hold no longer counts.
    static let slop: Double = 10

    /// A hold the page reported, read from the script message.
    struct Report: Equatable {
        let src: String
        let heldMs: Double
        let moved: Double
        let touches: Int

        init(src: String, heldMs: Double, moved: Double, touches: Int) {
            self.src = src
            self.heldMs = heldMs
            self.moved = moved
            self.touches = touches
        }

        /// nil unless every field is there. A message from an older script, or a site posting its own, is ignored.
        init?(body: Any) {
            guard let dict = body as? [String: Any],
                  let src = dict["src"] as? String, !src.isEmpty,
                  let held = dict["held"] as? NSNumber,
                  let moved = dict["moved"] as? NSNumber,
                  let touches = dict["touches"] as? NSNumber else { return nil }
            self.init(src: src, heldMs: held.doubleValue, moved: moved.doubleValue, touches: touches.intValue)
        }
    }

    /// Build 40: Zalla's own script world. The page's scripts run in another world and cannot reach this handler.
    @MainActor static var world: WKContentWorld { .defaultClient }

    /// Build 40: only a report from the top page, sent by Zalla's script in Zalla's world, is listened to. Ads and
    /// other embedded frames, and anything a site posts itself, are ignored.
    static func trusts(isMainFrame: Bool, fromZallaWorld: Bool) -> Bool {
        isMainFrame && fromZallaWorld
    }

    /// True only for one finger held still long enough while the page is not scrolling, and with no sheet already up.
    static func accepts(_ report: Report, scrolling: Bool, sheetShowing: Bool) -> Bool {
        guard !scrolling, !sheetShowing else { return false }
        return report.touches == 1 && report.heldMs >= minimumHoldMs && report.moved <= slop
    }

    /// Listens in the capture phase on window, so a site's own touch handlers (carousels that stop propagation) can't
    /// hide the end of a touch from it. Any movement past the slop, a second finger, touchcancel, touchend, any scroll
    /// (page or element), or the page being hidden ends the hold. Synthetic touches from page scripts are ignored, and
    /// a touch sequence fires at most once.
    static let script = """
    (function() {
      if (window.__zallaImageHook) return;
      window.__zallaImageHook = true;
      var HOLD = 550, SLOP = 10;
      var timer = null, hold = null;
      function cancel() {
        if (timer) { clearTimeout(timer); timer = null; }
        hold = null;
      }
      function send(h) {
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.zallaImage) {
            window.webkit.messageHandlers.zallaImage.postMessage({
              src: h.src, held: Date.now() - h.t, moved: h.moved, touches: 1
            });
          }
        } catch (e) {}
      }
      var opts = { passive: true, capture: true };
      window.addEventListener('touchstart', function(e) {
        cancel();
        if (!e.isTrusted || !e.touches || e.touches.length !== 1) return;
        var t = e.target;
        if (!t || t.tagName !== 'IMG') return;
        var src = t.currentSrc || t.src;
        if (!src) return;
        var p = e.touches[0];
        hold = { src: src, x: p.clientX, y: p.clientY, t: Date.now(), moved: 0,
                 sx: window.scrollX, sy: window.scrollY };
        timer = setTimeout(function() {
          timer = null;
          var h = hold;
          hold = null;
          if (!h) return;
          if (Math.abs(window.scrollX - h.sx) > SLOP || Math.abs(window.scrollY - h.sy) > SLOP) return;
          send(h);
        }, HOLD);
      }, opts);
      window.addEventListener('touchmove', function(e) {
        if (!hold) return;
        if (!e.touches || e.touches.length !== 1) { cancel(); return; }
        var p = e.touches[0];
        var d = Math.max(Math.abs(p.clientX - hold.x), Math.abs(p.clientY - hold.y));
        if (d > hold.moved) hold.moved = d;
        if (d > SLOP) cancel();
      }, opts);
      window.addEventListener('touchend', cancel, opts);
      window.addEventListener('touchcancel', cancel, opts);
      window.addEventListener('scroll', cancel, opts);
      window.addEventListener('gesturestart', cancel, opts);
      window.addEventListener('pagehide', cancel, opts);
      document.addEventListener('visibilitychange', cancel, opts);
    })();
    """
}
