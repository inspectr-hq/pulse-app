import XCTest
import SwiftUI
@testable import Pulse

final class SiteManagerViewTests: XCTestCase {
    func testMoveDropProposalUsesMoveOperation() {
        XCTAssertEqual(SiteManagerRowDropDelegate.moveDropProposal().operation, .move)
    }

    func testMetadataPatternPlaceholderMatchesExtractionMode() {
        XCTAssertEqual(MonitorFormView.patternPlaceholder(for: .jsonPath), "$.version")
        XCTAssertEqual(MonitorFormView.patternPlaceholder(for: .header), "X-Version")
        XCTAssertEqual(MonitorFormView.patternPlaceholder(for: .regex), "version=(.*)")
    }
}
