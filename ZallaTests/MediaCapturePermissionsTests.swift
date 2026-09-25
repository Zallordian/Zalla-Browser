import XCTest
@testable import Zalla

final class MediaCapturePermissionsTests: XCTestCase {
    func testSiteLabelHidesDefaultPorts() {
        XCTAssertEqual(MediaCapturePrompt.siteLabel(scheme: "https", host: "meet.test", port: 443), "meet.test")
        XCTAssertEqual(MediaCapturePrompt.siteLabel(scheme: "http", host: "meet.test", port: 80), "meet.test")
        XCTAssertEqual(MediaCapturePrompt.siteLabel(scheme: "https", host: "meet.test", port: 0), "meet.test")
        XCTAssertEqual(MediaCapturePrompt.siteLabel(scheme: "https", host: "meet.test", port: 8443), "meet.test:8443")
        XCTAssertEqual(MediaCapturePrompt.siteLabel(scheme: "https", host: "", port: 443), "This site")
    }

    func testPromptCopy() {
        XCTAssertEqual(
            MediaCapturePrompt.title(site: "meet.test", kind: .camera),
            "Allow meet.test to use your camera?"
        )
        XCTAssertEqual(MediaCapturePrompt.allowTitle, "Allow")
        XCTAssertEqual(MediaCapturePrompt.denyTitle, "Don't Allow")
        let dash = String(UnicodeScalar(0x2014)!)
        XCTAssertFalse(MediaCapturePrompt.message.contains(dash))
        for kind in MediaCaptureKind.allCases {
            XCTAssertFalse(MediaCapturePrompt.title(site: "a.test", kind: kind).contains(dash))
        }
    }

    func testMemoryIsPerSiteKindAndPrivacy() {
        var memory = MediaPermissionMemory()
        XCTAssertNil(memory.decision(site: "a.test", kind: .camera, isPrivate: false))
        memory.remember(true, site: "a.test", kind: .camera, isPrivate: false)
        XCTAssertEqual(memory.decision(site: "a.test", kind: .camera, isPrivate: false), true)
        XCTAssertNil(memory.decision(site: "a.test", kind: .microphone, isPrivate: false))
        XCTAssertNil(memory.decision(site: "b.test", kind: .camera, isPrivate: false))
        XCTAssertNil(memory.decision(site: "a.test", kind: .camera, isPrivate: true), "Private tabs keep separate choices")

        memory.remember(false, site: "b.test", kind: .microphone, isPrivate: false)
        XCTAssertEqual(memory.decision(site: "b.test", kind: .microphone, isPrivate: false), false)
    }

    func testCombinedGrantCoversSingleDevices() {
        var memory = MediaPermissionMemory()
        memory.remember(true, site: "a.test", kind: .cameraAndMicrophone, isPrivate: false)
        XCTAssertEqual(memory.decision(site: "a.test", kind: .camera, isPrivate: false), true)
        XCTAssertEqual(memory.decision(site: "a.test", kind: .microphone, isPrivate: false), true)

        var denied = MediaPermissionMemory()
        denied.remember(false, site: "a.test", kind: .cameraAndMicrophone, isPrivate: false)
        XCTAssertNil(denied.decision(site: "a.test", kind: .camera, isPrivate: false), "A combined denial still lets the site ask for one device")
    }

    func testRemoveAllClearsChoices() {
        var memory = MediaPermissionMemory()
        memory.remember(true, site: "a.test", kind: .camera, isPrivate: false)
        memory.removeAll()
        XCTAssertTrue(memory.isEmpty)
        XCTAssertNil(memory.decision(site: "a.test", kind: .camera, isPrivate: false))
    }
}
