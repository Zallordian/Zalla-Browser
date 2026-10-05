import XCTest
@testable import Zalla

final class BurnCopyTests: XCTestCase {
    func testBurnCopyNeverSaysTheAppQuits() {
        let banned = ["quit", "exit", "closes zalla", "zalla closes", "close the app", "closes the app", "restart"]
        for text in BurnCopy.all {
            let lower = text.lowercased()
            for word in banned {
                XCTAssertFalse(lower.contains(word), "\"\(text)\" should not contain \"\(word)\"")
            }
            XCTAssertFalse(text.contains("\u{2014}"))
            XCTAssertFalse(text.contains("\u{2013}"))
        }
    }

    func testConfirmationPromisesAFreshTabAndKeepsBookmarks() {
        XCTAssertTrue(BurnCopy.confirmationMessage.contains("fresh tab"))
        XCTAssertTrue(BurnCopy.confirmationMessage.contains("Bookmarks"))
        XCTAssertTrue(BurnCopy.menuFooter.contains("fresh tab"))
    }

    func testChangelogNeverSaysBurnItAllQuits() {
        for entry in Changelog.releases.prefix(2) {
            let text = (entry.highlights + [entry.improvements, entry.fixes]).joined(separator: " ").lowercased()
            XCTAssertFalse(text.contains("quit"), entry.version)
            // Build 32 is the entry that announced the new Burn It All behavior.
            if entry.version == "Build 32" {
                XCTAssertTrue(text.contains("fresh tab"), entry.version)
            }
        }
    }

    func testVideoSaverStaysOutOfUserFacingCopyWhileItIsOff() {
        guard !FeatureFlags.videoSaverEnabled else { return }
        for entry in Changelog.releases + Changelog.beta {
            let text = (entry.highlights + [entry.improvements, entry.fixes]).joined(separator: " ").lowercased()
            XCTAssertFalse(text.contains("video saver"), entry.version)
        }
        let suite = UserDefaults(suiteName: "zalla.tests.videosaver.flag") ?? .standard
        suite.set(true, forKey: VideoSaver.storageKey)
        XCTAssertFalse(VideoSaver.isEnabled(in: suite))
        suite.removeObject(forKey: VideoSaver.storageKey)
    }
}
