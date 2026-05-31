import XCTest
@testable import Pulse

final class SiteCheckerStatusCodeTests: XCTestCase {
    func testStatusCodeInterpretation() {
        XCTAssertTrue(SiteChecker.isUpStatusCode(200))
        XCTAssertTrue(SiteChecker.isUpStatusCode(301))
        XCTAssertTrue(SiteChecker.isUpStatusCode(399))

        XCTAssertFalse(SiteChecker.isUpStatusCode(400))
        XCTAssertFalse(SiteChecker.isUpStatusCode(404))
        XCTAssertFalse(SiteChecker.isUpStatusCode(500))
    }
}
