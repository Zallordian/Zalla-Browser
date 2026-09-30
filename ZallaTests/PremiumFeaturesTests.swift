import XCTest
@testable import Zalla

final class PremiumFeaturesTests: XCTestCase {
    private func freshDefaults(_ name: String = "PremiumFeaturesTests") -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testPrivateLockNeedsUnlockAndSetting() {
        let defaults = freshDefaults()
        XCTAssertFalse(PrivateTabLock.isRequired(unlocked: true, defaults: defaults))
        defaults.set(true, forKey: PrivateTabLock.storageKey)
        XCTAssertTrue(PrivateTabLock.isRequired(unlocked: true, defaults: defaults))
        XCTAssertFalse(PrivateTabLock.isRequired(unlocked: false, defaults: defaults))
    }

    func testAutoClearDueRules() {
        let now = Date()
        XCTAssertFalse(AutoClear.isDue(schedule: .off, lastRun: nil, now: now, ranThisLaunch: false))
        XCTAssertTrue(AutoClear.isDue(schedule: .onLaunch, lastRun: nil, now: now, ranThisLaunch: false))
        XCTAssertFalse(AutoClear.isDue(schedule: .onLaunch, lastRun: nil, now: now, ranThisLaunch: true))
        XCTAssertFalse(AutoClear.isDue(schedule: .daily, lastRun: nil, now: now, ranThisLaunch: false))
        XCTAssertFalse(AutoClear.isDue(schedule: .daily, lastRun: now.addingTimeInterval(-3_600), now: now, ranThisLaunch: false))
        XCTAssertTrue(AutoClear.isDue(schedule: .daily, lastRun: now.addingTimeInterval(-86_401), now: now, ranThisLaunch: false))
        XCTAssertFalse(AutoClear.isDue(schedule: .weekly, lastRun: now.addingTimeInterval(-86_400 * 3), now: now, ranThisLaunch: false))
        XCTAssertTrue(AutoClear.isDue(schedule: .weekly, lastRun: now.addingTimeInterval(-86_400 * 7), now: now, ranThisLaunch: false))
    }

    func testAutoClearSettingsRoundTripAndReset() {
        let defaults = freshDefaults("PremiumFeaturesTests.autoclear")
        XCTAssertEqual(AutoClear.schedule(defaults), .off)
        XCTAssertTrue(AutoClear.clearsHistory(defaults))
        XCTAssertNil(AutoClear.lastRun(defaults))
        defaults.set(AutoClearSchedule.weekly.rawValue, forKey: AutoClear.scheduleKey)
        AutoClear.recordRun(at: Date(timeIntervalSince1970: 1_000), in: defaults)
        XCTAssertEqual(AutoClear.schedule(defaults), .weekly)
        XCTAssertEqual(AutoClear.lastRun(defaults), Date(timeIntervalSince1970: 1_000))
        AutoClear.resetSettings(in: defaults)
        XCTAssertEqual(AutoClear.schedule(defaults), .off)
        XCTAssertNil(AutoClear.lastRun(defaults))
    }

    func testTabGroupsSaveLoadAndNames() {
        let defaults = freshDefaults("PremiumFeaturesTests.groups")
        XCTAssertTrue(TabGroupStore.load(from: defaults).isEmpty)
        let group = TabGroup(name: "Work", color: .green)
        TabGroupStore.save([group], to: defaults)
        XCTAssertEqual(TabGroupStore.load(from: defaults), [group])
        TabGroupStore.save([], to: defaults)
        XCTAssertTrue(TabGroupStore.load(from: defaults).isEmpty)
        XCTAssertNil(TabGroupStore.cleanedName("   "))
        XCTAssertEqual(TabGroupStore.cleanedName("  Trip  "), "Trip")
        XCTAssertEqual(TabGroupStore.cleanedName(String(repeating: "a", count: 40))?.count, TabGroupStore.maxNameLength)
    }

    func testGroupIDSurvivesSessionAndPrivateTabsDropIt() throws {
        let id = UUID()
        let snapshot = TabSession.snapshot(from: [
            TabSession.Source(isPrivate: false, url: URL(string: "https://a.test"), title: "A", isSelected: true, interactionState: nil, groupID: id),
            TabSession.Source(isPrivate: true, url: URL(string: "https://b.test"), title: "B", isSelected: false, interactionState: nil, groupID: id)
        ])
        XCTAssertEqual(snapshot.tabs.count, 1)
        let decoded = try XCTUnwrap(TabSession.decode(TabSession.encode(snapshot)))
        XCTAssertEqual(decoded.tabs.first?.groupID, id)
    }

    func testOldSessionWithoutGroupsStillDecodes() throws {
        let json = #"{"version":1,"tabs":[{"url":"https://a.test","title":"A"}],"selectedIndex":0}"#
        let decoded = try XCTUnwrap(TabSession.decode(Data(json.utf8)))
        XCTAssertNil(decoded.tabs.first?.groupID)
    }

    func testSpeechChunksRespectLimitAndOrder() {
        let long = String(repeating: "word ", count: 2_000)
        let chunks = SpeechText.chunks(title: "Hi", paragraphs: ["One.", "Two.", long, "", "Last."])
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 3_000 })
        XCTAssertTrue(chunks.first?.hasPrefix("Hi.\nOne.\nTwo.") == true)
        XCTAssertTrue(chunks.last?.hasSuffix("Last.") == true)
        XCTAssertTrue(SpeechText.chunks(title: "", paragraphs: []).isEmpty)
    }

    func testUnlockCopyListsEveryPremiumFeature() {
        let note = ZallaUnlockProduct.Copy.note.lowercased()
        for word in ["stronger blocking", "face id", "tab groups", "listen", "css", "auto-clear", "background packs", "theme packs"] {
            XCTAssertTrue(note.contains(word), word)
        }
        XCTAssertFalse(note.contains("\u{2014}"))
    }
}
