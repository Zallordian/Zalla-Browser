import XCTest
import WebKit
@testable import Zalla

@MainActor
final class PrivateTabTests: XCTestCase {
    func testPrivateTabsUseIsolatedMemoryStores() {
        let first = BrowserTab(isPrivate: true)
        let second = BrowserTab(isPrivate: true)
        XCTAssertFalse(first.webView.configuration.websiteDataStore.isPersistent)
        XCTAssertFalse(second.webView.configuration.websiteDataStore.isPersistent)
        XCTAssertFalse(first.webView.configuration.websiteDataStore === second.webView.configuration.websiteDataStore)
    }

    func testRegularTabUsesPersistentWebsiteStorage() {
        let tab = BrowserTab(isPrivate: false)
        XCTAssertTrue(tab.webView.configuration.websiteDataStore.isPersistent)
    }

    func testTabsAllowInlineMediaPlayback() {
        XCTAssertTrue(BrowserTab(isPrivate: false).webView.configuration.allowsInlineMediaPlayback)
    }

    func testPopupTabReusesOpenerConfiguration() {
        let opener = BrowserTab(isPrivate: true)
        let popup = BrowserTab(isPrivate: opener.isPrivate, configuration: opener.webView.configuration)
        XCTAssertTrue(popup.isPrivate)
        XCTAssertTrue(
            popup.webView.configuration.websiteDataStore === opener.webView.configuration.websiteDataStore,
            "Popups share the opener's data store so sign-in popups keep their session"
        )
    }

}
