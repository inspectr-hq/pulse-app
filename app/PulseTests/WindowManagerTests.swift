import XCTest
import AppKit
@testable import Pulse

final class WindowManagerTests: XCTestCase {
    func testHistoryWindowFrameUsesWiderDefaultSize() {
        let frame = historyWindowFrame()

        XCTAssertEqual(frame.width, 1_120)
        XCTAssertEqual(frame.height, 560)
    }

    func testCenteredOriginKeepsWindowHorizontallyCentered() {
        let frame = NSRect(x: 40, y: 200, width: 720, height: 620)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = windowCenteredOrigin(frame: frame, visibleFrame: visibleFrame)

        XCTAssertEqual(origin.x, 360)
        XCTAssertEqual(origin.y, 200)
    }

    func testCenteredOriginPreservesTopEdgeWhenProvided() {
        let frame = NSRect(x: 40, y: 200, width: 720, height: 620)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = windowCenteredOrigin(frame: frame, visibleFrame: visibleFrame, topEdge: 820)

        XCTAssertEqual(origin.x, 360)
        XCTAssertEqual(origin.y, 200)
    }
}
