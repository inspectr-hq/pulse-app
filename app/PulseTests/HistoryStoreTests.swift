import XCTest
@testable import Pulse

final class HistoryStoreTests: XCTestCase {
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
