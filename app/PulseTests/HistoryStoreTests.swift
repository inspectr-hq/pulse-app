import XCTest
@testable import Pulse

final class HistoryStoreTests: XCTestCase {
    func testMetadataFieldsPersistWhenPresent() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-metadata-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: tempURL)

        let event = HistoryEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            monitorID: UUID(),
            monitorName: "inspectr",
            url: "https://inspectr.dev",
            method: "GET",
            status: "OK",
            statusCode: 200,
            durationMs: 42,
            reason: nil,
            trigger: .manual,
            metadataLabel: "Version",
            metadataValue: "2.6.0"
        )

        store.append(event, retentionPolicy: .unlimited, maxEvents: 10)

        let reloaded = store.loadEvents()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.metadataLabel, "Version")
        XCTAssertEqual(reloaded.first?.metadataValue, "2.6.0")
    }

    func testOlderHistoryJSONDecodesWithoutMetadataFields() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-legacy-\(UUID().uuidString).json")
        let raw = """
        [
          {
            "id": "00000000-0000-0000-0000-000000000001",
            "timestamp": "2026-06-05T08:00:00Z",
            "monitorID": "00000000-0000-0000-0000-000000000002",
            "monitorName": "inspectr",
            "url": "https://inspectr.dev",
            "method": "GET",
            "status": "OK",
            "statusCode": 200,
            "durationMs": 42,
            "reason": null,
            "trigger": "manual"
          }
        ]
        """
        try raw.write(to: tempURL, atomically: true, encoding: .utf8)

        let store = HistoryStore(fileURL: tempURL)
        let events = store.loadEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events.first?.metadataLabel)
        XCTAssertNil(events.first?.metadataValue)
    }

    func testRetentionIsBounded() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: tempURL)

        for index in 0..<6 {
            store.append(
                HistoryEvent(
                    timestamp: Date(),
                    monitorID: UUID(),
                    monitorName: "m\(index)",
                    url: "https://example.com",
                    method: "GET",
                    status: "OK",
                    statusCode: 200,
                    durationMs: 120,
                    reason: nil,
                    trigger: .automatic
                ),
                retentionPolicy: .unlimited,
                maxEvents: 3
            )
        }

        XCTAssertEqual(store.loadEvents().count, 3)
    }

    func testPersistsISO8601DateStrings() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-iso-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: tempURL)

        store.append(
            HistoryEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                monitorID: UUID(),
                monitorName: "inspectr",
                url: "https://inspectr.dev",
                method: "GET",
                status: "OK",
                statusCode: 200,
                durationMs: 42,
                reason: nil,
                trigger: .manual
            ),
            retentionPolicy: .unlimited,
            maxEvents: 10
        )

        let raw = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(raw.contains("timestamp"))
        XCTAssertTrue(raw.contains("T"))
        XCTAssertTrue(raw.contains("Z"))
    }

    func testCorruptFileFallsBackToEmpty() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-corrupt-\(UUID().uuidString).json")
        try "not-json".write(to: tempURL, atomically: true, encoding: .utf8)

        let store = HistoryStore(fileURL: tempURL)
        XCTAssertEqual(store.loadEvents(), [])
    }
}
