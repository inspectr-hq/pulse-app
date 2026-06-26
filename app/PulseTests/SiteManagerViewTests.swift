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

    func testConfigurationExportIncludesMonitorsAndSettings() throws {
        let monitor = SiteMonitor(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            url: URL(string: "https://inspectr.dev")!,
            displayName: "Inspectr",
            method: .get,
            thresholdMs: 1500,
            createdAt: Date(timeIntervalSince1970: 1_782_464_400)
        )
        var settings = AppSettings()
        settings.defaultThresholdMs = 1500
        let exportedAt = Date(timeIntervalSince1970: 1_782_550_800)

        let data = try SiteManagerView.configurationExportData(
            monitors: [monitor],
            settings: settings,
            exportedAt: exportedAt
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(SiteManagerView.ConfigurationExport.self, from: data)
        let jsonString = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(export.appName, "Pulse")
        XCTAssertEqual(export.exportedAt, exportedAt)
        XCTAssertEqual(export.monitors, [monitor])
        XCTAssertEqual(export.settings.defaultThresholdMs, 1500)
        XCTAssertFalse(jsonString.contains("\\/"))
    }
}
