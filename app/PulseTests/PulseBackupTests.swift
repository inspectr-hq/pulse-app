import XCTest
@testable import Pulse

final class PulseBackupTests: XCTestCase {
    func testFullBackupRoundTripsConfigurationAndHistory() throws {
        let monitor = SiteMonitor(url: URL(string: "https://example.com")!, displayName: "Example")
        let event = HistoryEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000), monitorID: monitor.id, monitorName: "Example",
            url: monitor.url.absoluteString, method: "GET", status: "OK", statusCode: 200,
            durationMs: 42, reason: nil, trigger: .automatic
        )
        let backup = PulseBackup(monitors: [monitor], settings: AppSettings(), history: [event])

        let decoded = try PulseBackup.decode(backup.encodedData())

        XCTAssertEqual(decoded, backup)
    }

    func testBackupRejectsUnsupportedVersion() throws {
        let json = """
        {"formatVersion": 2, "appName": "Pulse", "appVersion": "1.0", "exportedAt": "2026-08-28T00:00:00Z", "monitors": [], "settings": {}, "history": []}
        """

        XCTAssertThrowsError(try PulseBackup.decode(Data(json.utf8)))
    }
}
