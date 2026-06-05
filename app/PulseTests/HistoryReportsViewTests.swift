import XCTest
@testable import Pulse

final class HistoryReportsViewTests: XCTestCase {
    func testHistoryMetadataTextCombinesLabelAndValue() {
        let event = HistoryEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            monitorID: UUID(),
            monitorName: "Site A",
            url: "https://a.dev",
            method: "GET",
            status: "OK",
            statusCode: 200,
            durationMs: 42,
            reason: nil,
            trigger: .manual,
            metadataLabel: "Version",
            metadataValue: "2.6.0"
        )

        XCTAssertEqual(HistoryView.metadataText(for: event), "Version: 2.6.0")
    }

    func testHistoryMetadataTextFallsBackToDashWithoutMetadata() {
        let event = HistoryEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            monitorID: UUID(),
            monitorName: "Site A",
            url: "https://a.dev",
            method: "GET",
            status: "OK",
            statusCode: 200,
            durationMs: 42,
            reason: nil,
            trigger: .manual
        )

        XCTAssertEqual(HistoryView.metadataText(for: event), "-")
    }

    func testTooltipIsBelowForFirstRow() {
        XCTAssertTrue(HistoryReportsView.tooltipShouldRenderBelow(rowIndex: 0))
    }

    func testTooltipIsAboveForLaterRows() {
        XCTAssertFalse(HistoryReportsView.tooltipShouldRenderBelow(rowIndex: 1))
        XCTAssertFalse(HistoryReportsView.tooltipShouldRenderBelow(rowIndex: 3))
    }

    func testMetadataMarkerTitleUsesLabelAndValue() {
        let marker = HistoryViewModel.MetadataMarker(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            label: "Version",
            value: "2.6.0"
        )

        XCTAssertEqual(HistoryReportsView.metadataMarkerTitle(for: marker), "Version 2.6.0")
    }

    func testMetadataMarkersRenderOnlyForSingleSiteSelection() {
        XCTAssertFalse(HistoryReportsView.shouldShowMetadataMarkers(for: "All Sites"))
        XCTAssertTrue(HistoryReportsView.shouldShowMetadataMarkers(for: "Site A"))
    }
}
