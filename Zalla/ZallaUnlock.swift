import Foundation
import StoreKit

/// Zalla Unlock: the one time, non-consumable purchase behind paid features. This is the single
/// entitlement check for every paid feature, so new paywalls should read `ZallaUnlock.shared`.
enum ZallaUnlockProduct {
    static let id = "com.zalla.browser.unlock"

    /// True when a verified transaction for the unlock is present and not revoked.
    static func grants(productID: String, revocationDate: Date?) -> Bool {
        productID == id && revocationDate == nil
    }

    /// The entitlement to keep after reading StoreKit. A verified purchase wins. An unverified result
    /// for the unlock proves nothing either way, so the cached answer stays. Verified absence turns it off.
    static func resolvedEntitlement(verifiedOwned: Bool, sawUnverifiedUnlock: Bool, cached: Bool) -> Bool {
        if verifiedOwned { return true }
        if sawUnverifiedUnlock { return cached }
        return false
    }

    enum Copy {
        static let title = "Zalla Unlock"
        static let subtitle = "One time purchase"
        static let note = "Stronger blocking, Face ID for private tabs, tab groups, listen to page, per-site CSS, scheduled auto-clear, background packs, and the Space and Jungle theme packs. Buy once, keep it on this Apple Account."
        static let unavailable = "Unlock isn't available yet."
        static let pending = "Your purchase is waiting for approval."
        static let failed = "The purchase did not go through. Please try again later."
        static let restoreNone = "No previous Zalla Unlock purchase was found for this Apple Account."
        static let unlocked = "Zalla Unlock is active. Thank you!"
    }
}

/// Last known entitlement, stored on this device so paid features work offline and at launch
/// before StoreKit answers. StoreKit stays the source of truth and corrects this on refresh.
enum ZallaUnlockCache {
    static let key = "zallaUnlockEntitled"

    static func load(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func save(_ unlocked: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(unlocked, forKey: key)
    }
}

@MainActor
final class ZallaUnlock: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case restoring
        case pending
        case failed(String)
        case message(String)
    }

    static let shared = ZallaUnlock()

    @Published private(set) var isUnlocked: Bool
    @Published private(set) var product: Product?
    @Published private(set) var loadState: LoadState = .idle
    @Published var purchaseState: PurchaseState = .idle

    /// Called on the main actor whenever the entitlement changes.
    var onChange: ((Bool) -> Void)?

    private init() {
        isUnlocked = ZallaUnlockCache.load()
    }

    var isBusy: Bool {
        purchaseState == .purchasing || purchaseState == .restoring
    }

    func loadProduct() async {
        if loadState == .loading || (loadState == .loaded && product != nil) { return }
        loadState = .loading
        do {
            let products = try await Product.products(for: [ZallaUnlockProduct.id])
            product = products.first
            loadState = product == nil ? .unavailable : .loaded
        } catch {
            product = nil
            loadState = .unavailable
        }
    }

    func purchase() async {
        guard let product, !isBusy else { return }
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    setUnlocked(ZallaUnlockProduct.grants(productID: transaction.productID, revocationDate: transaction.revocationDate))
                    await transaction.finish()
                    purchaseState = .message(ZallaUnlockProduct.Copy.unlocked)
                case .unverified(let transaction, _):
                    await transaction.finish()
                    purchaseState = .failed(ZallaUnlockProduct.Copy.failed)
                }
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(ZallaUnlockProduct.Copy.failed)
        }
    }

    /// Restore Purchases: syncs with the App Store (may ask to sign in), then rereads entitlements.
    func restore() async {
        guard !isBusy else { return }
        purchaseState = .restoring
        do {
            try await AppStore.sync()
        } catch {
            // Cancelled sign in or offline: still check what is already on this device.
        }
        await refreshEntitlements()
        purchaseState = .message(isUnlocked ? ZallaUnlockProduct.Copy.unlocked : ZallaUnlockProduct.Copy.restoreNone)
    }

    /// Reads current entitlements from StoreKit and updates the cache.
    func refreshEntitlements() async {
        var owned = false
        var sawUnverifiedUnlock = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if ZallaUnlockProduct.grants(productID: transaction.productID, revocationDate: transaction.revocationDate) {
                    owned = true
                }
            case .unverified(let transaction, _):
                if transaction.productID == ZallaUnlockProduct.id { sawUnverifiedUnlock = true }
            }
        }
        setUnlocked(ZallaUnlockProduct.resolvedEntitlement(
            verifiedOwned: owned, sawUnverifiedUnlock: sawUnverifiedUnlock, cached: ZallaUnlockCache.load()
        ))
    }

    /// Transaction.updates for the unlock product: purchases approved later, refunds, and revocations.
    func apply(productID: String, revocationDate: Date?) {
        guard productID == ZallaUnlockProduct.id else { return }
        setUnlocked(ZallaUnlockProduct.grants(productID: productID, revocationDate: revocationDate))
    }

    private func setUnlocked(_ unlocked: Bool) {
        ZallaUnlockCache.save(unlocked)
        guard unlocked != isUnlocked else { return }
        isUnlocked = unlocked
        onChange?(unlocked)
    }
}
