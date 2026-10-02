import UIKit

/// Whether the on-screen keyboard is up. Lets a pull down on a page put the keyboard away instead of also reloading.
@MainActor
final class KeyboardVisibility: NSObject {
    static let shared = KeyboardVisibility()

    private(set) var isVisible = false

    private override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow() { isVisible = true }
    @objc private func keyboardWillHide() { isVisible = false }
}
