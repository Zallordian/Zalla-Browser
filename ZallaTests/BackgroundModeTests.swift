import XCTest
@testable import Zalla

/// Build 51: the shipped app must not declare a background mode. Audio was rejected under guideline 2.5.4.
final class BackgroundModeTests: XCTestCase {
    func testNoModeIsAllowed() {
        XCTAssertTrue(BackgroundModePolicy.disallowed(in: nil).isEmpty)
        XCTAssertTrue(BackgroundModePolicy.disallowed(in: []).isEmpty)
        XCTAssertEqual(BackgroundModePolicy.disallowed(in: ["audio"]), ["audio"])
        XCTAssertEqual(BackgroundModePolicy.disallowed(in: ["audio", "location"]), ["audio", "location"])
    }

    func testProjectFileDoesNotDeclareABackgroundMode() throws {
        let yaml = try projectYAML()
        XCTAssertFalse(
            BackgroundModePolicy.projectDeclaresABackgroundMode(yaml),
            "project.yml still contains UIBackgroundModes, which XcodeGen writes into the shipped Info.plist"
        )
    }

    func testShippedBundlesDoNotDeclareBackgroundModes() {
        // The app plist when this test is hosted in Zalla, plus the test bundle itself.
        let bundles = [Bundle.main, Bundle(for: PageSpeaker.self), Bundle(for: BackgroundModeTests.self)]
        for bundle in bundles {
            let modes = bundle.infoDictionary?["UIBackgroundModes"] as? [String]
            XCTAssertEqual(
                BackgroundModePolicy.disallowed(in: modes), [],
                "\(bundle.bundleIdentifier ?? "bundle") declares \(modes ?? [])"
            )
        }
    }

    private func projectYAML() throws -> String {
        let bundle = Bundle(for: BackgroundModeTests.self)
        let url = bundle.url(forResource: "project", withExtension: "yml")
            ?? bundle.url(forResource: "project.yml", withExtension: nil)
        let resolved = try XCTUnwrap(url, "project.yml was not copied into the test bundle")
        return try String(contentsOf: resolved, encoding: .utf8)
    }
}
