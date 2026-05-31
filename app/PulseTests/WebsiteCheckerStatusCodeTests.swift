import XCTest
@testable import Pulse

final class WebsiteCheckerStatusCodeTests: XCTestCase {
    func testStatusCodeInterpretation() {
        XCTAssertTrue(WebsiteChecker.isUpStatusCode(200))
        XCTAssertTrue(WebsiteChecker.isUpStatusCode(301))
        XCTAssertTrue(WebsiteChecker.isUpStatusCode(399))

        XCTAssertFalse(WebsiteChecker.isUpStatusCode(400))
        XCTAssertFalse(WebsiteChecker.isUpStatusCode(404))
        XCTAssertFalse(WebsiteChecker.isUpStatusCode(500))
    }
}
