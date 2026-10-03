import XCTest
@testable import Zalla

final class VideoSaverTests: XCTestCase {
    private func url(_ text: String) -> URL { URL(string: text)! }

    func testClassifiesFilesPlaylistsAndEverythingElse() {
        XCTAssertEqual(VideoSaver.classify(url("https://cdn.example.com/a/clip.mp4")), .file)
        XCTAssertEqual(VideoSaver.classify(url("https://cdn.example.com/clip.MOV?token=1")), .file)
        XCTAssertEqual(VideoSaver.classify(url("http://example.com/clip.m4v")), .file)
        XCTAssertEqual(VideoSaver.classify(url("https://example.com/clip.webm#t=5")), .file)
        XCTAssertEqual(VideoSaver.classify(url("https://example.com/live/master.m3u8")), .hls)
        XCTAssertEqual(VideoSaver.classify(url("https://example.com/manifest.mpd")), .unsupported)
        XCTAssertEqual(VideoSaver.classify(url("https://example.com/watch?v=abc")), .unsupported)
        XCTAssertEqual(VideoSaver.classify(url("blob:https://example.com/1234")), .unsupported)
        XCTAssertEqual(VideoSaver.classify(url("data:video/mp4;base64,AAAA")), .unsupported)
        XCTAssertEqual(VideoSaver.classify(url("file:///var/clip.mp4")), .unsupported)
        XCTAssertEqual(VideoSaver.classify(url("ftp://example.com/clip.mp4")), .unsupported)
    }

    func testCandidatesDropRepeatsAndUnsupportedAndCapTheList() {
        let list = VideoSaver.candidates(from: [
            "https://example.com/a.mp4",
            "https://example.com/a.mp4#t=3",
            "https://example.com/page.html",
            "blob:https://example.com/9",
            "  https://example.com/b.m3u8  ",
            "not a url"
        ])
        XCTAssertEqual(list.map(\.url.absoluteString), ["https://example.com/a.mp4", "https://example.com/b.m3u8"])
        XCTAssertEqual(list.map(\.kind), [.file, .hls])
        let many = (0..<20).map { "https://example.com/\($0).mp4" }
        XCTAssertEqual(VideoSaver.candidates(from: many).count, VideoSaver.maxCandidates)
    }

    func testDisplayNameFallsBackToTheHost() {
        XCTAssertEqual(VideoSaver.Candidate(url: url("https://example.com/v/clip.mp4"), kind: .file).displayName, "clip.mp4")
        XCTAssertEqual(VideoSaver.Candidate(url: url("https://example.com/"), kind: .hls).displayName, "example.com")
    }

    func testReportParsingAndAvailability() {
        let body: [String: Any] = ["sources": ["https://example.com/a.mp4", 5, "https://example.com/x"], "protected": true]
        let report = VideoSaver.report(from: body)
        XCTAssertEqual(report?.candidates.count, 1)
        XCTAssertEqual(report?.protectedMedia, true)
        XCTAssertEqual(report.map(VideoSaver.availability(for:)), .ready)
        XCTAssertNil(VideoSaver.report(from: "text"))
        let onlyKeyed = VideoSaver.Report(candidates: [], protectedMedia: true)
        XCTAssertEqual(VideoSaver.availability(for: onlyKeyed), .protected)
        XCTAssertEqual(VideoSaver.availability(for: VideoSaver.Report(candidates: [], protectedMedia: false)), .none)
    }

    func testAttributeListsHandleQuotedCommas() {
        let values = VideoSaver.attributes("METHOD=AES-128,URI=\"https://k.example.com/key,1\",IV=0x1234")
        XCTAssertEqual(values["METHOD"], "AES-128")
        XCTAssertEqual(values["URI"], "https://k.example.com/key,1")
        XCTAssertEqual(values["IV"], "0x1234")
    }

    func testMediaPlaylistThatIsPlainAndFinishedIsNotProtected() {
        let text = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:6
        #EXTINF:6.0,
        seg0.ts
        #EXTINF:6.0,
        seg1.ts
        #EXT-X-ENDLIST
        """
        let info = VideoSaver.parseHLS(text)
        XCTAssertEqual(info?.segmentCount, 2)
        XCTAssertEqual(info?.isMaster, false)
        XCTAssertEqual(info?.isLive, false)
        XCTAssertEqual(info?.isProtected, false)
        XCTAssertEqual(VideoSaver.message(forStream: info), VideoSaver.streamMessage)
    }

    func testPlaylistWithoutAnEndIsLive() {
        let info = VideoSaver.parseHLS("#EXTM3U\n#EXTINF:6.0,\nseg0.ts\n")
        XCTAssertEqual(info?.isLive, true)
        XCTAssertEqual(VideoSaver.message(forStream: info), VideoSaver.liveMessage)
    }

    func testMasterPlaylistListsVariantsAndPicksTheBest() {
        let text = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
        low/index.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=2400000,RESOLUTION=1280x720
        high/index.m3u8
        """
        let info = VideoSaver.parseHLS(text)
        XCTAssertEqual(info?.isMaster, true)
        XCTAssertEqual(info?.variants.count, 2)
        XCTAssertEqual(info?.bestVariant?.uri, "high/index.m3u8")
        XCTAssertEqual(info?.bestVariant?.resolution, "1280x720")
        XCTAssertEqual(info?.isLive, false)
    }

    func testEncryptedAndKeyedPlaylistsAreProtected() {
        func protected(_ keyLine: String) -> Bool? {
            VideoSaver.parseHLS("#EXTM3U\n\(keyLine)\n#EXTINF:6.0,\nseg0.ts\n#EXT-X-ENDLIST\n")?.isProtected
        }
        XCTAssertEqual(protected("#EXT-X-KEY:METHOD=AES-128,URI=\"https://k.example.com/k\""), true)
        XCTAssertEqual(protected("#EXT-X-KEY:METHOD=SAMPLE-AES,URI=\"skd://abc\",KEYFORMAT=\"com.apple.streamingkeydelivery\",KEYFORMATVERSIONS=\"1\""), true)
        XCTAssertEqual(protected("#EXT-X-KEY:METHOD=SAMPLE-AES-CTR,URI=\"data:text/plain;base64,AAAA\",KEYFORMAT=\"urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed\""), true)
        XCTAssertEqual(protected("#EXT-X-SESSION-KEY:METHOD=SAMPLE-AES,URI=\"skd://abc\""), true)
        // METHOD=NONE means not encrypted.
        XCTAssertEqual(protected("#EXT-X-KEY:METHOD=NONE"), false)
        XCTAssertEqual(
            VideoSaver.message(forStream: VideoSaver.parseHLS("#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"k\"\n#EXTINF:6,\ns.ts\n#EXT-X-ENDLIST")),
            VideoSaver.protectedMessage
        )
    }

    func testNonPlaylistTextIsNotParsed() {
        XCTAssertNil(VideoSaver.parseHLS("<html></html>"))
        XCTAssertEqual(VideoSaver.message(forStream: nil), VideoSaver.unreadableMessage)
    }

    func testAvailabilityNeedsUnlockAndTheSwitch() {
        XCTAssertTrue(VideoSaver.isAvailable(unlocked: true, enabled: true))
        XCTAssertFalse(VideoSaver.isAvailable(unlocked: false, enabled: true))
        XCTAssertFalse(VideoSaver.isAvailable(unlocked: true, enabled: false))
        XCTAssertTrue(VideoSaver.settingsFooter(unlocked: false).contains("Zalla Unlock"))
        XCTAssertFalse(VideoSaver.settingsFooter(unlocked: true).contains("needs Zalla Unlock"))
    }

    func testScriptOnlyReadsAndHasNoSiteSpecificCode() {
        let script = VideoSaver.script
        XCTAssertTrue(script.contains("zallaVideo"))
        XCTAssertTrue(script.contains("mediaKeys"))
        XCTAssertFalse(script.contains("fetch("))
        XCTAssertFalse(script.contains("XMLHttpRequest"))
        XCTAssertFalse(script.lowercased().contains("youtube"))
        XCTAssertFalse(script.contains("\u{2014}"))
        for text in [VideoSaver.protectedMessage, VideoSaver.noVideoMessage, VideoSaver.streamMessage, VideoSaver.liveMessage, VideoSaver.unreadableMessage] {
            XCTAssertFalse(text.contains("\u{2014}"))
            XCTAssertFalse(text.contains("\u{2013}"))
        }
        XCTAssertEqual(VideoSaver.protectedMessage, "This video is protected and can't be saved.")
    }
}
