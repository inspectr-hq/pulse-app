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

    func testHistoryRefreshButtonUsesExpectedSymbol() {
        XCTAssertEqual(HistoryView.refreshButtonSymbolName, "arrow.clockwise")
    }

    func testHistoryRefreshButtonUsesExpectedHelpText() {
        XCTAssertEqual(HistoryView.refreshButtonHelpText, "Refresh history")
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

    func testChartXAxisLabelStyleUsesTimeFor24Hours() {
        XCTAssertEqual(
            HistoryReportsView.chartXAxisLabelStyle(for: .last24h),
            .hourMinute
        )
    }

    func testChartXAxisLabelStyleUsesDateForLongerRanges() {
        XCTAssertEqual(
            HistoryReportsView.chartXAxisLabelStyle(for: .last7d),
            .monthDay
        )
        XCTAssertEqual(
            HistoryReportsView.chartXAxisLabelStyle(for: .last30d),
            .monthDay
        )
        XCTAssertEqual(
            HistoryReportsView.chartXAxisLabelStyle(for: .last90d),
            .monthDay
        )
    }

    func testMetadataMarkerAnnotationAlignmentUsesTrailingNearRightEdge() {
        let marker = HistoryViewModel.MetadataMarker(
            timestamp: Date(timeIntervalSince1970: 190),
            label: "Version",
            value: "2.6.0"
        )
        let domain = Date(timeIntervalSince1970: 100)...Date(timeIntervalSince1970: 200)

        XCTAssertEqual(
            HistoryReportsView.metadataMarkerAnnotationAlignment(for: marker, in: domain),
            .trailing
        )
    }

    func testMetadataMarkerAnnotationAlignmentUsesLeadingNearLeftEdge() {
        let marker = HistoryViewModel.MetadataMarker(
            timestamp: Date(timeIntervalSince1970: 110),
            label: "Version",
            value: "2.6.0"
        )
        let domain = Date(timeIntervalSince1970: 100)...Date(timeIntervalSince1970: 200)

        XCTAssertEqual(
            HistoryReportsView.metadataMarkerAnnotationAlignment(for: marker, in: domain),
            .leading
        )
    }

    func testMetadataMarkerAnnotationAlignmentUsesCenterAwayFromEdges() {
        let marker = HistoryViewModel.MetadataMarker(
            timestamp: Date(timeIntervalSince1970: 150),
            label: "Version",
            value: "2.6.0"
        )
        let domain = Date(timeIntervalSince1970: 100)...Date(timeIntervalSince1970: 200)

        XCTAssertEqual(
            HistoryReportsView.metadataMarkerAnnotationAlignment(for: marker, in: domain),
            .center
        )
    }

    func testMetadataMarkerAnnotationVerticalOffsetKeepsBalloonLowerInChart() {
        XCTAssertEqual(HistoryReportsView.metadataMarkerAnnotationYOffset, 18)
    }

    func testMetadataMarkerBackgroundOpacityIsSemiTransparent() {
        XCTAssertEqual(HistoryReportsView.metadataMarkerBackgroundOpacity, 0.78, accuracy: 0.001)
    }
}
