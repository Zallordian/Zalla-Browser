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
            ZallaUnlockProduct.Copy.restoreNone, ZallaUnlockProduct.Copy.unlocked
        ]
        XCTAssertFalse(copy.contains { $0.contains("\u{2014}") })
        XCTAssertEqual(ZallaUnlockProduct.Copy.unavailable, "Unlock isn't available yet.")
    }
}
