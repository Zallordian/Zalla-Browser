import XCTest
@testable import Zalla

final class TipJarTests: XCTestCase {
    func testProductIDs() {
        XCTAssertEqual(TipJar.productIDs, [
            "com.zalla.browser.tip.small",
            "com.zalla.browser.tip.medium",
            "com.zalla.browser.tip.large"
        ])
        XCTAssertTrue(TipJar.isTipProduct("com.zalla.browser.tip.medium"))
        XCTAssertFalse(TipJar.isTipProduct("com.zalla.browser.pro"))
    }

    func testSortedByPriceCheapestFirst() {
        let items: [(id: String, price: Decimal)] = [
            (TipJar.largeID, Decimal(string: "4.99")!),
            (TipJar.smallID, Decimal(string: "0.99")!),
            (TipJar.mediumID, Decimal(string: "2.99")!)
        ]
        let sorted = TipJar.sortedByPrice(items, id: { $0.id }, price: { $0.price })
        XCTAssertEqual(sorted.map(\.id), [TipJar.smallID, TipJar.mediumID, TipJar.largeID])
    }

    func testEqualPricesKeepSizeOrder() {
        let items: [(id: String, price: Decimal)] = [
            (TipJar.largeID, 1),
            (TipJar.mediumID, 1),
            (TipJar.smallID, 1)
        ]
        let sorted = TipJar.sortedByPrice(items, id: { $0.id }, price: { $0.price })
        XCTAssertEqual(sorted.map(\.id), [TipJar.smallID, TipJar.mediumID, TipJar.largeID])
    }

    func testSupporterState() {
        let defaults = UserDefaults(suiteName: "TipJarTests")!
        defaults.removePersistentDomain(forName: "TipJarTests")
        XCTAssertFalse(SupporterState.isSupporter(in: defaults))
        XCTAssertEqual(SupporterState.tipCount(in: defaults), 0)
        SupporterState.recordTip(in: defaults)
        SupporterState.recordTip(in: defaults)
        XCTAssertTrue(SupporterState.isSupporter(in: defaults))
        XCTAssertEqual(SupporterState.tipCount(in: defaults), 2)
        defaults.removePersistentDomain(forName: "TipJarTests")
    }

    func testCopyHasNoDashes() {
        let dash = String(UnicodeScalar(0x2014)!)
        let copy = [
            TipJar.Copy.note, TipJar.Copy.unavailable, TipJar.Copy.pending,
            TipJar.Copy.failed, TipJar.Copy.thanksTitle, TipJar.Copy.thanksMessage
        ]
        for line in copy {
            XCTAssertFalse(line.contains(dash), line)
        }
        XCTAssertTrue(TipJar.Copy.note.contains("do not unlock features"))
    }
}
