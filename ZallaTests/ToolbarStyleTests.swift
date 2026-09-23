import XCTest
@testable import Zalla

final class ToolbarStyleTests: XCTestCase {
    func testDefaultRawValues() {
        XCTAssertEqual(ToolbarStyle.classic.rawValue, "Classic")
        XCTAssertEqual(ToolbarStyle.compact.rawValue, "Compact")
        XCTAssertEqual(ToolbarStyle.storageKey, "toolbarStyle")
    }
}
