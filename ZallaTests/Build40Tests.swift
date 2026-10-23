import XCTest
@testable import Zalla

final class Build40Tests: XCTestCase {
    func testLibraryWritesStayReadableWhileLocked() {
        XCTAssertTrue(LibraryBackup.writeOptions.contains(.completeFileProtectionUntilFirstUserAuthentication))
        XCTAssertFalse(LibraryBackup.writeOptions.contains(.completeFileProtection))
        XCTAssertTrue(LibraryBackup.writeOptions.contains(.atomic))
    }

    func testUnreadableLibraryIsCopiedAside() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("library.json")
        try Data("not json".utf8).write(to: file)
        let copy = LibraryBackup.copyURL(for: file, date: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(copy.lastPathComponent, "library-unreadable-100.json")
        LibraryBackup.keepCopy(of: file)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertEqual(names.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "The original stays where it was")
    }

    func testInterruptedDownloadsComeBackAsFailed() {
        let url = URL(string: "https://example.com/file.zip")!
        let running = DownloadRecord(filename: "file.zip", sourceURL: url, state: .downloading)
        let done = DownloadRecord(filename: "done.zip", sourceURL: url, state: .completed)
        let result = DownloadsStore.recovered([running, done], fileExists: { _ in false })
        XCTAssertEqual(result[0].state, .failed)
        XCTAssertEqual(result[0].errorMessage, DownloadsStore.interruptedMessage)
        XCTAssertEqual(result[1], done)
        XCTAssertTrue(DownloadsStore.canRetry(result[0]))
    }

    func testOnlyWebDownloadsCanBeRetried() {
        let blob = DownloadRecord(filename: "a", sourceURL: URL(string: "blob:download")!, state: .failed)
        let web = DownloadRecord(filename: "a", sourceURL: URL(string: "https://example.com/a")!, state: .failed)
        let running = DownloadRecord(filename: "a", sourceURL: URL(string: "https://example.com/a")!, state: .downloading)
        XCTAssertFalse(DownloadsStore.canRetry(blob))
        XCTAssertTrue(DownloadsStore.canRetry(web))
        XCTAssertFalse(DownloadsStore.canRetry(running))
    }

    func testImageHoldOnlyTrustsZallasScriptOnTheTopPage() {
        XCTAssertTrue(ImageHold.trusts(isMainFrame: true, fromZallaWorld: true))
        XCTAssertFalse(ImageHold.trusts(isMainFrame: false, fromZallaWorld: true), "Ads and embedded frames are ignored")
        XCTAssertFalse(ImageHold.trusts(isMainFrame: true, fromZallaWorld: false), "A site posting its own message is ignored")
    }

    func testPrivacyCoverOnlyAfterRealBackgrounding() {
        XCTAssertFalse(PrivacyCover.showsCover(enabled: true, phase: .inactive, current: false), "Control Center and sheets leave the page")
        XCTAssertTrue(PrivacyCover.showsCover(enabled: true, phase: .background, current: false))
        XCTAssertTrue(PrivacyCover.showsCover(enabled: true, phase: .inactive, current: true), "Stays up on the way back")
        XCTAssertFalse(PrivacyCover.showsCover(enabled: true, phase: .active, current: true))
        XCTAssertFalse(PrivacyCover.showsCover(enabled: false, phase: .background, current: false))
        XCTAssertTrue(PrivacyCover.defaultEnabled, "Privacy is the default")
        let suite = UserDefaults(suiteName: "zalla.tests.cover")!
        suite.removePersistentDomain(forName: "zalla.tests.cover")
        XCTAssertTrue(PrivacyCover.enabled(in: suite))
    }

    func testEncryptedDNSCopyIsPlainAboutScope() {
        let detail = PrivacyShield.Copy.encryptedDNSDetail
        XCTAssertTrue(detail.contains("Zalla makes on its own"))
        XCTAssertTrue(detail.contains("Web pages you visit still use your iPhone's normal DNS"))
        for text in [detail, PrivacyShield.Copy.dnsRestartNote, PrivacyCover.title] {
            XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"))
            XCTAssertFalse(text.contains("VPN"))
        }
    }

    func testBlockerWaitIsShort() {
        XCTAssertGreaterThan(ContentBlocker.launchWait, 0)
        XCTAssertLessThanOrEqual(ContentBlocker.launchWait, 3)
    }

    func testVersionIsOneZero() {
        XCTAssertEqual(Changelog.releases.first?.version, "1.0")
        XCTAssertEqual(ZallaUnlockProduct.Copy.subtitle, "One-time purchase")
    }
}
