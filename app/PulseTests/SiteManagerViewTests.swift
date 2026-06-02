import XCTest
import SwiftUI
@testable import Pulse

final class SiteManagerViewTests: XCTestCase {
    func testMoveDropProposalUsesMoveOperation() {
        XCTAssertEqual(SiteManagerRowDropDelegate.moveDropProposal().operation, .move)
    }
}
