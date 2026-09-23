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

}
