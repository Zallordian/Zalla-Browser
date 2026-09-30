import Foundation

/// Closes cookie consent banners for you by choosing the "reject" or "only necessary" button. It never clicks accept.
/// It only looks for known buttons and button wording, runs in the main page, and stops after a few seconds.
enum CookieBannerDismiss {
    static let storageKey = "cookieBannerAutoDismiss"
    static let messageName = "zallaCookie"

    static var isEnabled: Bool { enabled(in: .standard) }

    static func enabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? true
    }

    static let script = #"""
    (function() {
      if (window.__zallaCookieBanner) return;
      window.__zallaCookieBanner = true;
      var selectors = [
        '#onetrust-reject-all-handler', '.ot-pc-refuse-all-handler', '#CybotCookiebotDialogBodyButtonDecline',
        '#CybotCookiebotDialogBodyLevelButtonLevelOptinDeclineAll', '.cmp-reject-all', '#didomi-notice-disagree-button',
        '.truste-button2', '#truste-consent-required', 'button[data-testid="reject-all"]', 'button[id*="reject-all"]',
        'button[class*="reject-all"]', '#cookie-reject', '.js-cookie-reject', '.cc-deny', '.cookie-decline'
      ];
      var phrases = [
        'reject all', 'reject', 'decline all', 'decline', 'deny all', 'deny', 'refuse all', 'refuse',
        'only necessary', 'necessary only', 'only essential', 'essential only', 'use necessary cookies only',
        'continue without accepting', 'no thanks', 'disagree'
      ];
      var done = false;
      var tries = 0;
      function visible(el) {
        if (!el || !el.getBoundingClientRect) return false;
        var r = el.getBoundingClientRect();
        var s = window.getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
      }
      function report() {
        try {
          window.webkit.messageHandlers.zallaCookie.postMessage({ host: location.hostname });
        } catch (e) {}
      }
      function insideBanner(el) {
        var node = el;
        for (var i = 0; node && i < 8; i++, node = node.parentElement) {
          var text = ((node.id || '') + ' ' + (node.className && node.className.toString ? node.className.toString() : '') +
            ' ' + (node.getAttribute ? (node.getAttribute('role') || '') + ' ' + (node.getAttribute('aria-label') || '') : '')).toLowerCase();
          if (/cookie|consent|gdpr|privacy|cmp|onetrust|didomi|cookiebot|truste|dialog/.test(text)) return true;
        }
        return false;
      }
      function attempt() {
        if (done) return;
        tries++;
        for (var i = 0; i < selectors.length; i++) {
          var el = document.querySelector(selectors[i]);
          if (el && visible(el)) { el.click(); done = true; report(); return; }
        }
        var buttons = document.querySelectorAll('button, [role="button"], a.button, input[type="button"], input[type="submit"]');
        for (var j = 0; j < buttons.length; j++) {
          var b = buttons[j];
          var label = ((b.innerText || b.value || b.getAttribute('aria-label') || '') + '').trim().toLowerCase();
          if (!label || label.length > 40 || !visible(b)) continue;
          for (var k = 0; k < phrases.length; k++) {
            if (label === phrases[k] && insideBanner(b)) { b.click(); done = true; report(); return; }
          }
        }
      }
      var timer = setInterval(function() {
        attempt();
        if (done || tries > 12) clearInterval(timer);
      }, 500);
    })();
    """#
}
