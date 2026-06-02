import XCTest
@testable import Pulse

final class HistoryReportsViewTests: XCTestCase {
    func testTooltipIsBelowForFirstRow() {
        XCTAssertTrue(HistoryReportsView.tooltipShouldRenderBelow(rowIndex: 0))
    }

    func testTooltipIsAboveForLaterRows() {
        XCTAssertFalse(HistoryReportsView.tooltipShouldRenderBelow(rowIndex: 1))
        XCTAssertFalse(HistoryReportsView.tooltipShouldRenderBelow(rowIndex: 3))
    }
}
