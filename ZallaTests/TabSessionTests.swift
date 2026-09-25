import XCTest
@testable import Zalla

final class TabSessionTests: XCTestCase {
    private func source(
        _ url: String?,
        title: String = "Page",
        isPrivate: Bool = false,
        selected: Bool = false,
        state: Data? = nil
    ) -> TabSession.Source {
        TabSession.Source(
            isPrivate: isPrivate,
            url: url.flatMap { URL(string: $0) },
            title: title,
            isSelected: selected,
            interactionState: state
        )
    }

    func testSnapshotNeverIncludesPrivateTabs() {
        let snapshot = TabSession.snapshot(from: [
            source("https://a.test", title: "A"),
            source("https://secret.test", title: "Secret", isPrivate: true, selected: true),
            source("https://b.test", title: "B")
        ])
        XCTAssertEqual(snapshot.tabs.map(\.url.host), ["a.test", "b.test"])
        XCTAssertFalse(snapshot.tabs.contains { $0.url.host == "secret.test" })
        XCTAssertNil(snapshot.selectedIndex, "A private selected tab is not remembered")
    }

    func testSnapshotSkipsBlankAndNonWebTabsAndKeepsSelection() {
        let snapshot = TabSession.snapshot(from: [
            source(nil),
            source("about:blank"),
            source("file:///etc/hosts"),
            source("https://a.test", title: "A"),
            source("http://b.test", title: "B", selected: true)
        ])
        XCTAssertEqual(snapshot.tabs.count, 2)
        XCTAssertEqual(snapshot.selectedIndex, 1)
        XCTAssertEqual(snapshot.tabs[1].title, "B")
    }

    func testEmptyTitleFallsBackToHost() {
        let snapshot = TabSession.snapshot(from: [source("https://www.example.com/x", title: "  ")])
        XCTAssertEqual(snapshot.tabs.first?.title, "www.example.com")
    }

    func testOversizedInteractionStateIsDropped() {
        let big = Data(count: TabSession.maxInteractionStateBytes + 1)
        let small = Data([1, 2, 3])
        let snapshot = TabSession.snapshot(from: [
            source("https://a.test", state: big),
            source("https://b.test", state: small)
        ])
        XCTAssertNil(snapshot.tabs[0].interactionState)
        XCTAssertEqual(snapshot.tabs[1].interactionState, small)
    }

    func testTabCountIsCapped() {
        let many = (0..<(TabSession.maxTabs + 10)).map { source("https://site\($0).test") }
        XCTAssertEqual(TabSession.snapshot(from: many).tabs.count, TabSession.maxTabs)
    }

    func testEncodeDecodeRoundTrip() throws {
        let snapshot = TabSession.snapshot(from: [
            source("https://a.test", title: "A", state: Data([9, 8, 7])),
            source("https://b.test", title: "B", selected: true)
        ])
        let data = try TabSession.encode(snapshot)
        XCTAssertEqual(TabSession.decode(data), snapshot)
    }

    func testDecodeRejectsGarbageAndNewerVersions() throws {
        XCTAssertNil(TabSession.decode(Data("not json".utf8)))
        var future = TabSessionSnapshot(tabs: [TabSessionEntry(url: URL(string: "https://a.test")!, title: "A")])
        future.version = TabSessionSnapshot.currentVersion + 1
        XCTAssertNil(TabSession.decode(try JSONEncoder().encode(future)))
    }

    func testDecodeSanitizesUnsafeEntriesAndSelection() throws {
        let raw = TabSessionSnapshot(
            tabs: [
                TabSessionEntry(url: URL(string: "javascript:alert(1)")!, title: "Bad"),
                TabSessionEntry(url: URL(string: "https://a.test")!, title: "A")
            ],
            selectedIndex: 7
        )
        let decoded = TabSession.decode(try JSONEncoder().encode(raw))
        XCTAssertEqual(decoded?.tabs.map(\.title), ["A"])
        XCTAssertEqual(decoded?.selectedIndex, 0)
    }

    func testSaveLoadAndClearOnDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(TabSession.fileName)
        let snapshot = TabSession.snapshot(from: [source("https://a.test", title: "A", selected: true)])
        try TabSession.save(snapshot, to: url)
        XCTAssertEqual(TabSession.load(from: url), snapshot)

        // Saving an empty session (for example after Reset) removes the file.
        try TabSession.save(TabSessionSnapshot(), to: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(TabSession.load(from: url))

        try TabSession.save(snapshot, to: url)
        TabSession.clear(at: url)
        XCTAssertNil(TabSession.load(from: url))
    }
}
