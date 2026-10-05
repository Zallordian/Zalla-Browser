import XCTest
@testable import Zalla

final class ZallaUnlockTests: XCTestCase {
    func testProductID() {
        XCTAssertEqual(ZallaUnlockProduct.id, "com.zalla.browser.unlock")
        XCTAssertFalse(TipJar.isTipProduct(ZallaUnlockProduct.id))
    }

    func testGrantsOnlyForUnrevokedUnlock() {
        XCTAssertTrue(ZallaUnlockProduct.grants(productID: ZallaUnlockProduct.id, revocationDate: nil))
        XCTAssertFalse(ZallaUnlockProduct.grants(productID: ZallaUnlockProduct.id, revocationDate: Date()))
        XCTAssertFalse(ZallaUnlockProduct.grants(productID: TipJar.smallID, revocationDate: nil))
    }

    func testUnverifiedResultNeverRevokesACachedPurchase() {
        XCTAssertTrue(ZallaUnlockProduct.resolvedEntitlement(verifiedOwned: true, sawUnverifiedUnlock: false, cached: false))
        XCTAssertTrue(ZallaUnlockProduct.resolvedEntitlement(verifiedOwned: false, sawUnverifiedUnlock: true, cached: true))
        XCTAssertFalse(ZallaUnlockProduct.resolvedEntitlement(verifiedOwned: false, sawUnverifiedUnlock: true, cached: false))
        XCTAssertFalse(ZallaUnlockProduct.resolvedEntitlement(verifiedOwned: false, sawUnverifiedUnlock: false, cached: true))
    }

    func testCacheRoundTrip() {
        let defaults = UserDefaults(suiteName: "ZallaUnlockTests")!
        defaults.removePersistentDomain(forName: "ZallaUnlockTests")
        XCTAssertFalse(ZallaUnlockCache.load(from: defaults))
        ZallaUnlockCache.save(true, to: defaults)
        XCTAssertTrue(ZallaUnlockCache.load(from: defaults))
        ZallaUnlockCache.save(false, to: defaults)
        XCTAssertFalse(ZallaUnlockCache.load(from: defaults))
        defaults.removePersistentDomain(forName: "ZallaUnlockTests")
    }

    func testCopyHasNoEmDashes() {
        let copy = [
            ZallaUnlockProduct.Copy.title, ZallaUnlockProduct.Copy.subtitle, ZallaUnlockProduct.Copy.note,
            ZallaUnlockProduct.Copy.unavailable, ZallaUnlockProduct.Copy.pending, ZallaUnlockProduct.Copy.failed,
            ZallaUnlockProduct.Copy.restoreNone, ZallaUnlockProduct.Copy.unlocked,
            ZallaUnlockProduct.Copy.restoreOffline, ZallaUnlockProduct.Copy.tryAgain, ZallaUnlockProduct.Copy.notOffered
        ]
        XCTAssertFalse(copy.contains { $0.contains("\u{2014}") })
        XCTAssertFalse(copy.contains { $0.contains("\u{2013}") })
        XCTAssertTrue(ZallaUnlockProduct.Copy.unavailable.contains("App Store"))
    }

    func testUnavailableMessageSeparatesErrorFromEmptyAnswer() {
        XCTAssertEqual(ZallaUnlockProduct.unavailableMessage(loadFailed: true), ZallaUnlockProduct.Copy.unavailable)
        XCTAssertEqual(ZallaUnlockProduct.unavailableMessage(loadFailed: false), ZallaUnlockProduct.Copy.notOffered)
        XCTAssertTrue(ZallaUnlockProduct.Copy.unavailable.contains("Couldn't reach the App Store"))
        XCTAssertFalse(ZallaUnlockProduct.Copy.notOffered.contains("App Store"))
    }

    func testRestoreMessageSeparatesOfflineFromNone() {
        XCTAssertEqual(ZallaUnlockProduct.restoreMessage(unlocked: true, reachedStore: false), ZallaUnlockProduct.Copy.unlocked)
        XCTAssertEqual(ZallaUnlockProduct.restoreMessage(unlocked: false, reachedStore: true), ZallaUnlockProduct.Copy.restoreNone)
        XCTAssertEqual(ZallaUnlockProduct.restoreMessage(unlocked: false, reachedStore: false), ZallaUnlockProduct.Copy.restoreOffline)
    }
}
