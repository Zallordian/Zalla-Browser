import SwiftUI
import WebKit

/// Scripts for Hide Element. They run in WebKit's client content world, so pages cannot see or
/// call them. The pick script resolves to a CSS selector for the tapped element, or "" when cancelled.
enum ElementPicker {
    static let pickScript = """
    return await new Promise(function (resolve) {
      if (window.__zallaPicker) { window.__zallaPicker.finish(''); }
      var root = document.documentElement;
      if (!root) { resolve(''); return; }
      var shield = document.createElement('div');
      shield.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;z-index:2147483646;background:transparent;touch-action:none;';
      var box = document.createElement('div');
      box.style.cssText = 'position:fixed;z-index:2147483647;pointer-events:none;display:none;border:2px solid #E33B4F;background:rgba(227,59,79,0.18);border-radius:4px;box-sizing:border-box;';
      var current = null;
      function escape(value) {
        if (window.CSS && CSS.escape) { return CSS.escape(value); }
        return value.replace(/[^a-zA-Z0-9_-]/g, '\\\\$&');
      }
      function unique(selector) {
        try { return document.querySelectorAll(selector).length === 1; } catch (e) { return false; }
      }
      function selectorFor(element) {
        if (element.id && unique('#' + escape(element.id))) { return '#' + escape(element.id); }
        var parts = [];
        var node = element;
        while (node && node.nodeType === 1 && node !== document.body && node !== root && parts.length < 6) {
          var part = node.tagName.toLowerCase();
          if (node.id) {
            parts.unshift(part + '#' + escape(node.id));
            break;
          }
          var classes = Array.prototype.filter.call(node.classList, function (name) {
            return /^[a-zA-Z_][a-zA-Z0-9_-]{0,39}$/.test(name);
          }).slice(0, 2);
          if (classes.length) { part += '.' + classes.map(escape).join('.'); }
          var parent = node.parentElement;
          if (parent) {
            var same = Array.prototype.filter.call(parent.children, function (child) {
              return child.tagName === node.tagName;
            });
            if (same.length > 1) { part += ':nth-of-type(' + (same.indexOf(node) + 1) + ')'; }
          }
          parts.unshift(part);
          if (unique(parts.join(' > '))) { break; }
          node = parent;
        }
        return parts.join(' > ');
      }
      function elementAt(x, y) {
        shield.style.pointerEvents = 'none';
        var element = document.elementFromPoint(x, y);
        shield.style.pointerEvents = 'auto';
        if (!element || element === root || element === document.body || element === box) { return null; }
        return element;
      }
      function highlight(element) {
        current = element;
        if (!element) { box.style.display = 'none'; return; }
        var rect = element.getBoundingClientRect();
        box.style.left = rect.left + 'px';
        box.style.top = rect.top + 'px';
        box.style.width = rect.width + 'px';
        box.style.height = rect.height + 'px';
        box.style.display = 'block';
      }
      function point(event) {
        if (event.touches && event.touches.length) { return event.touches[0]; }
        if (event.changedTouches && event.changedTouches.length) { return event.changedTouches[0]; }
        return event;
      }
      function track(event) {
        event.preventDefault();
        var p = point(event);
        highlight(elementAt(p.clientX, p.clientY));
      }
      function choose(event) {
        event.preventDefault();
        var p = point(event);
        var element = elementAt(p.clientX, p.clientY) || current;
        finish(element ? selectorFor(element) : '');
      }
      function finish(value) {
        shield.remove();
        box.remove();
        window.__zallaPicker = null;
        resolve(value);
      }
      shield.addEventListener('touchstart', track, { passive: false });
      shield.addEventListener('touchmove', track, { passive: false });
      shield.addEventListener('touchend', choose, { passive: false });
      shield.addEventListener('click', choose, false);
      root.appendChild(shield);
      root.appendChild(box);
      window.__zallaPicker = { finish: finish };
    });
    """

    static let cancelScript = "if (window.__zallaPicker) { window.__zallaPicker.finish(''); } true;"

    static let hideScript = """
    try {
      document.querySelectorAll(selector).forEach(function (element) {
        element.style.setProperty('display', 'none', 'important');
      });
    } catch (e) {}
    return true;
    """
}

extension BrowserTab {
    /// Hide Element: tap something on the page to hide it on this site from now on.
    func beginElementPicker() {
        guard !isPickingElement, let host = contentBlockingHost else { return }
        isPickingElement = true
        webView.callAsyncJavaScript(ElementPicker.pickScript, arguments: [:], in: nil, in: .defaultClient) { [weak self] result in
            let selector = (try? result.get()) as? String ?? ""
            Task { @MainActor in
                self?.finishElementPicker(selector: selector, host: host)
            }
        }
    }

    func cancelElementPicker() {
        guard isPickingElement else { return }
        webView.evaluateJavaScript(ElementPicker.cancelScript, in: nil, in: .defaultClient, completionHandler: nil)
        isPickingElement = false
    }

    private func finishElementPicker(selector: String, host: String) {
        isPickingElement = false
        guard ContentBlockingSettings.isAcceptableSelector(selector) else { return }
        ContentBlocker.shared.update { $0.addHiddenElement(selector: selector, host: host) }
        // Hide it now too; the saved rule covers the next loads of this site.
        webView.callAsyncJavaScript(
            ElementPicker.hideScript, arguments: ["selector": selector], in: nil, in: .defaultClient, completionHandler: nil
        )
    }
}

/// Shown at the top of the page while Hide Element is waiting for a tap.
struct ElementPickerBanner: View {
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Tap an element to hide it on this site.")
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Cancel", action: onCancel)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }
}
