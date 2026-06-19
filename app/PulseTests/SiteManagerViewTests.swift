import XCTest
import SwiftUI
@testable import Pulse

final class SiteManagerViewTests: XCTestCase {
    func testMoveDropProposalUsesMoveOperation() {
        XCTAssertEqual(SiteManagerRowDropDelegate.moveDropProposal().operation, .move)
    }

    func testRemoveConfirmationTextUsesSiteName() {
        let monitor = SiteMonitor(url: URL(string: "https://example.com")!, displayName: "Example Site")

        XCTAssertEqual(SiteManagerView.removeConfirmationTitle, "Remove Site?")
        XCTAssertEqual(
            SiteManagerView.removeConfirmationMessage(for: monitor),
            "Are you sure you want to remove \"Example Site\"? This cannot be undone."
        )
    }

    func testMetadataPatternPlaceholderMatchesExtractionMode() {
        XCTAssertEqual(MonitorFormView.patternPlaceholder(for: .jsonPath), "$.version")
        XCTAssertEqual(MonitorFormView.patternPlaceholder(for: .header), "X-Version")
        XCTAssertEqual(MonitorFormView.patternPlaceholder(for: .regex), "version=(.*)")
    }
}
