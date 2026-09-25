import Foundation
import StoreKit

/// Product IDs, ordering, and copy for the Support Zalla tip jar. Tips are consumable in-app
/// purchases: a thank you that never unlocks features.
enum TipJar {
    static let smallID = "com.zalla.browser.tip.small"
    static let mediumID = "com.zalla.browser.tip.medium"
    static let largeID = "com.zalla.browser.tip.large"
    static let productIDs = [smallID, mediumID, largeID]

    static func isTipProduct(_ id: String) -> Bool {
        productIDs.contains(id)
    }

    /// Cheapest first. Ties keep the small, medium, large order.
    static func sortedByPrice<T>(_ items: [T], id: (T) -> String, price: (T) -> Decimal) -> [T] {
        items.sorted { lhs, rhs in
            let left = price(lhs)
            let right = price(rhs)
            if left != right { return left < right }
            return order(of: id(lhs)) < order(of: id(rhs))
        }
    }

    private static func order(of id: String) -> Int {
        productIDs.firstIndex(of: id) ?? productIDs.count
    }

    enum Copy {
        static let note = "Zalla is made by one person. If it makes your browsing better, a tip helps keep it going. Tips are a thank you and do not unlock features."
        static let unavailable = "Tips aren't available yet. Thanks for wanting to help!"
        static let pending = "Your tip is waiting for approval. Thank you for thinking of Zalla!"
        static let failed = "The tip did not go through. Please try again later."
        static let thanksTitle = "Thank you!"
        static let thanksMessage = "Your support means a lot and helps keep Zalla independent."
    }
}

/// Local record that you have tipped. Stored on this device only.
enum SupporterState {
    static let supporterKey = "tipJarSupporter"
    static let tipCountKey = "tipJarTipCount"

    static func isSupporter(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: supporterKey)
    }

    static func tipCount(in defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: tipCountKey)
    }

    static func recordTip(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: supporterKey)
        defaults.set(tipCount(in: defaults) + 1, forKey: tipCountKey)
    }
}

/// Finishes tip transactions that arrive outside the purchase button, such as an approved
/// Ask to Buy request or a purchase interrupted by the app closing.
enum TipTransactionObserver {
    private static var isStarted = false

    /// Call once at launch.
    static func start() {
        guard !isStarted else { return }
        isStarted = true
        Task.detached(priority: .background) {
            for await result in Transaction.unfinished {
                await handle(result)
            }
            for await result in Transaction.updates {
                await handle(result)
            }
        }
    }

    private static func handle(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            guard TipJar.isTipProduct(transaction.productID) else { return }
            if transaction.revocationDate == nil {
                await MainActor.run { SupporterState.recordTip() }
            }
            await transaction.finish()
        case .unverified(let transaction, _):
            guard TipJar.isTipProduct(transaction.productID) else { return }
            await transaction.finish()
        }
    }
}

/// Loads tip products and runs purchases for the Support Zalla screen.
@MainActor
final class TipStore: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing(String)
        case pending
        case thanked
        case failed
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published var purchaseState: PurchaseState = .idle

    var isPurchasing: Bool {
        if case .purchasing = purchaseState { return true }
        return false
    }

    func loadProducts() async {
        if loadState == .loading || (loadState == .loaded && !products.isEmpty) { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: TipJar.productIDs)
            let sorted = TipJar.sortedByPrice(loaded, id: { $0.id }, price: { $0.price })
            products = sorted
            loadState = sorted.isEmpty ? .unavailable : .loaded
        } catch {
            products = []
            loadState = .unavailable
        }
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        purchaseState = .purchasing(product.id)
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    SupporterState.recordTip()
                    purchaseState = .thanked
                case .unverified(let transaction, _):
                    await transaction.finish()
                    purchaseState = .failed
                }
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed
        }
    }
}
