import XCTest
@testable import Pulse

final class URLInputTests: XCTestCase {
    func testNormalizeAddsHTTPSForBareHost() {
        let normalized = URLInput.normalize("example.com")
        XCTAssertEqual(normalized?.absoluteString, "https://example.com")
    }

    func testNormalizeKeepsExistingScheme() {
        let normalized = URLInput.normalize("https://inspectr.dev")
        XCTAssertEqual(normalized?.absoluteString, "https://inspectr.dev")
    }

    func testNormalizeRejectsEmptyInput() {
        XCTAssertNil(URLInput.normalize("   \n\t  "))
    }
}
