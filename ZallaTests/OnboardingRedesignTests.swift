import XCTest
@testable import Zalla

/// Redesign phase 3: six setup screens, honest search ratings, and an unlock list that matches the real gates.
final class OnboardingRedesignTests: XCTestCase {
    func testSixScreensInOrder() {
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .look, .search, .bringStuff, .unlock, .farewell])
        XCTAssertEqual(OnboardingStep.allCases.map(\.rawValue), Array(0..<6))
    }

    func testEveryOfferedEngineHasADatedRating() {
        for engine in SearchEngine.allCases where engine != .custom {
            let rating = SearchEnginePrivacy.rating(for: engine)
            XCTAssertNotNil(rating, "\(engine) needs a rating")
            XCTAssertEqual(rating?.policyURL.scheme, "https")
        }
        XCTAssertNil(SearchEnginePrivacy.rating(for: .custom))
        XCTAssertTrue(SearchEnginePrivacy.Copy.footer.contains(SearchEnginePrivacy.ratedOn))
    }

    func testRatingsMatchThePlan() {
        let levels = Dictionary(uniqueKeysWithValues: SearchEngine.allCases.compactMap { engine in
            SearchEnginePrivacy.rating(for: engine).map { (engine, $0.level) }
        })
        XCTAssertEqual(levels[.brave], .collectsLittle)
        XCTAssertEqual(levels[.duckDuckGo], .collectsLittle)
        XCTAssertEqual(levels[.startpage], .collectsLittle)
        XCTAssertEqual(levels[.kagi], .collectsLittle)
        XCTAssertEqual(levels[.ecosia], .collectsSome)
        XCTAssertEqual(levels[.google], .collectsALot)
        XCTAssertEqual(levels[.bing], .collectsALot)
    }

    func testSetupOrderPutsDefaultFirstAndLeastPrivateLast() {
        let order = SearchEnginePrivacy.setupOrder(SearchEngine.allCases.filter { $0 != .custom })
        XCTAssertEqual(order.first, SearchEngine.defaultEngine)
        XCTAssertEqual(Set(order.suffix(2)), [.google, .bing])
        XCTAssertEqual(order.count, SearchEngine.allCases.count - 1)
    }

    func testRuleCountsNeverOverstate() {
        XCTAssertEqual(ZallaUnlockBenefits.approximate(111_942), "about 111,000")
        XCTAssertEqual(ZallaUnlockBenefits.approximate(28_999), "about 28,000")
        XCTAssertNil(ZallaUnlockBenefits.approximate(999))
        XCTAssertNil(ZallaUnlockBenefits.approximate(0))
    }

    func testUnlockListOnlyNamesGatedThings() {
        XCTAssertTrue(ZallaUnlockBenefits.unlockCategories.allSatisfy(\.requiresUnlock))
        XCTAssertTrue(ZallaUnlockBenefits.freeCategories.allSatisfy { !$0.requiresUnlock })
        let titles = ZallaUnlockBenefits.unlockItems(manifest: nil).map(\.title)
        XCTAssertEqual(titles.contains("Video Saver"), FeatureFlags.videoSaverEnabled)
    }

    func testCopyIsPlain() {
        var copy = [
            SearchEnginePrivacy.Copy.title, SearchEnginePrivacy.Copy.zallaPromise, SearchEnginePrivacy.Copy.enginesNote,
            SearchEnginePrivacy.Copy.footer, SearchEnginePrivacy.customNote,
            ZallaUnlockBenefits.Copy.title, ZallaUnlockBenefits.Copy.subtitle, ZallaUnlockBenefits.Copy.smallPrint,
            ZallaUnlockBenefits.Copy.notNow, ZallaUnlockBenefits.Copy.restore, ZallaUnlockBenefits.Copy.unlocked
        ]
        copy += SearchEngine.allCases.compactMap { SearchEnginePrivacy.rating(for: $0)?.reason }
        copy += (ZallaUnlockBenefits.unlockItems(manifest: nil) + ZallaUnlockBenefits.freeItems(manifest: nil)).flatMap { [$0.title, $0.detail] }
        for line in copy {
            XCTAssertFalse(line.contains("\u{2014}"), "No em dashes: \(line)")
            XCTAssertFalse(line.localizedCaseInsensitiveContains("family sharing"), "Family Sharing isn't on yet: \(line)")
            XCTAssertFalse(line.contains("$"), "Prices come from StoreKit: \(line)")
        }
        XCTAssertEqual(ZallaUnlockBenefits.Copy.notNow, "Not right now")
        XCTAssertEqual(ZallaUnlockBenefits.Copy.restore, "Restore Purchase")
    }
}
