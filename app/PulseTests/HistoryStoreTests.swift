import XCTest
@testable import Pulse

final class HistoryStoreTests: XCTestCase {
    func testMetadataFieldsPersistWhenPresent() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-metadata-\(UUID().uuidString).sqlite")
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
            .appendingPathComponent("pulse-history-legacy-\(UUID().uuidString).sqlite")
        let legacyURL = tempURL.deletingPathExtension().appendingPathExtension("json")
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
        try raw.write(to: legacyURL, atomically: true, encoding: .utf8)

        let store = HistoryStore(fileURL: tempURL)
        let events = store.loadEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events.first?.metadataLabel)
        XCTAssertNil(events.first?.metadataValue)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    func testRetentionIsBounded() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-\(UUID().uuidString).sqlite")
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
            .appendingPathComponent("pulse-history-iso-\(UUID().uuidString).sqlite")
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

        let reloaded = store.loadEvents()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.timestamp, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testCorruptFileFallsBackToEmpty() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-corrupt-\(UUID().uuidString).sqlite")
        try "not-json".write(to: tempURL.deletingPathExtension().appendingPathExtension("json"), atomically: true, encoding: .utf8)

        let store = HistoryStore(fileURL: tempURL)
        XCTAssertEqual(store.loadEvents(), [])
    }

    func testMergeDeduplicatesByEventID() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-merge-\(UUID().uuidString).sqlite")
        let store = HistoryStore(fileURL: tempURL)
        let event = HistoryEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000), monitorID: UUID(), monitorName: "A", url: "https://a.com", method: "GET",
            status: "OK", statusCode: 200, durationMs: 10, reason: nil, trigger: .automatic
        )

        store.merge([event, event], retentionPolicy: .unlimited, maxEvents: 100)

        XCTAssertEqual(store.loadEvents(), [event])
    }

    func testQueryFiltersSearchesOrdersAndLimitsEvents() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-query-\(UUID().uuidString).sqlite")
        let store = HistoryStore(fileURL: tempURL)
        let monitorID = UUID()
        let events = [
            HistoryEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_100), monitorID: monitorID,
                monitorName: "Example", url: "https://example.com/ok", method: "GET", status: "OK",
                statusCode: 200, durationMs: 20, reason: nil, trigger: .automatic
            ),
            HistoryEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_200), monitorID: monitorID,
                monitorName: "Example", url: "https://example.com/outage", method: "GET", status: "Down",
                statusCode: 503, durationMs: nil, reason: "timeout", trigger: .automatic,
                metadataLabel: "Region", metadataValue: "EU"
            ),
            HistoryEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_300), monitorID: UUID(),
                monitorName: "Other", url: "https://other.dev", method: "GET", status: "OK",
                statusCode: 200, durationMs: 30, reason: nil, trigger: .manual
            )
        ]
        store.merge(events, retentionPolicy: .unlimited, maxEvents: 100)

        let query = HistoryQuery(
            search: "eu",
            monitorID: monitorID,
            monitorName: "Example",
            status: .down,
            since: Date(timeIntervalSince1970: 1_700_000_150)
        )

        XCTAssertEqual(store.queryEvents(matching: query, order: .ascending, limit: 1), [events[1]])
    }

    func testQueryReturnsCompleteHistoryWithoutApplyingUIFilters() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-query-all-\(UUID().uuidString).sqlite")
        let store = HistoryStore(fileURL: tempURL)
        let events = (0..<3).map { index in
            HistoryEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)), monitorID: UUID(),
                monitorName: "Site \(index)", url: "https://example.com/\(index)", method: "GET", status: "OK",
                statusCode: 200, durationMs: index, reason: nil, trigger: .automatic
            )
        }
        store.merge(events, retentionPolicy: .unlimited, maxEvents: 100)

        XCTAssertEqual(
            store.queryEvents(matching: .all, order: .descending, limit: nil),
            events.reversed()
        )
    }

    func testQuerySupportsUpperTimestampBoundForGraphRanges() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-query-range-\(UUID().uuidString).sqlite")
        let store = HistoryStore(fileURL: tempURL)
        let events = (0..<3).map { index in
            HistoryEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)), monitorID: UUID(),
                monitorName: "Site", url: "https://example.com/\(index)", method: "GET", status: "OK",
                statusCode: 200, durationMs: index, reason: nil, trigger: .automatic
            )
        }
        store.merge(events, retentionPolicy: .unlimited, maxEvents: 100)

        let query = HistoryQuery(
            monitorName: "Site",
            since: Date(timeIntervalSince1970: 1_700_000_001),
            until: Date(timeIntervalSince1970: 1_700_000_001.5)
        )

        XCTAssertEqual(store.queryEvents(matching: query, order: .ascending, limit: nil), [events[1]])
    }

    func testAggregateCalculatesStatusAndLatencyMetricsInSQLite() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-aggregate-\(UUID().uuidString).sqlite")
        let store = HistoryStore(fileURL: tempURL)
        let monitorID = UUID()
        let events = [
            HistoryEvent(timestamp: Date(timeIntervalSince1970: 1_700_000_000), monitorID: monitorID, monitorName: "Site", url: "https://site.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 100, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: Date(timeIntervalSince1970: 1_700_000_001), monitorID: monitorID, monitorName: "Site", url: "https://site.dev", method: "GET", status: "Down", statusCode: nil, durationMs: 300, reason: "timeout", trigger: .automatic),
            HistoryEvent(timestamp: Date(timeIntervalSince1970: 1_700_000_002), monitorID: monitorID, monitorName: "Site", url: "https://site.dev", method: "GET", status: "OK", statusCode: 200, durationMs: nil, reason: nil, trigger: .automatic)
        ]
        store.merge(events, retentionPolicy: .unlimited, maxEvents: 100)

        let aggregate = store.aggregate(matching: HistoryQuery(monitorName: "Site"))

        XCTAssertEqual(aggregate.sampleCount, 3)
        XCTAssertEqual(aggregate.successCount, 2)
        XCTAssertEqual(aggregate.latencySampleCount, 2)
        XCTAssertEqual(aggregate.averageLatencyMs, 200)
        XCTAssertEqual(aggregate.peakLatencyMs, 300)
        XCTAssertEqual(store.percentileLatency(0.95, matching: HistoryQuery(monitorName: "Site")), 300)
    }

    func testTrackingValuesAreGroupedAndReturnFirstDetectionInSQLite() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-tracking-\(UUID().uuidString).sqlite")
        let store = HistoryStore(fileURL: tempURL)
        let monitorID = UUID()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let events = [
            HistoryEvent(timestamp: first, monitorID: monitorID, monitorName: "Site", url: "https://site.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 100, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "1.0"),
            HistoryEvent(timestamp: first.addingTimeInterval(1), monitorID: monitorID, monitorName: "Site", url: "https://site.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 100, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "1.0"),
            HistoryEvent(timestamp: first.addingTimeInterval(2), monitorID: monitorID, monitorName: "Site", url: "https://site.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 100, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.0")
        ]
        store.merge(events, retentionPolicy: .unlimited, maxEvents: 100)

        XCTAssertEqual(
            store.trackingValues(for: "Site"),
            [
                HistoryTrackingValue(label: "Version", value: "2.0", firstDetectedAt: first.addingTimeInterval(2)),
                HistoryTrackingValue(label: "Version", value: "1.0", firstDetectedAt: first)
            ]
        )
    }

    func testMonitorNamesAreReturnedDistinctAndSortedFromSQLite() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-history-names-\(UUID().uuidString).sqlite")
        let store = HistoryStore(fileURL: tempURL)
        let events = ["Zulu", "Alpha", "Zulu"].enumerated().map { index, name in
            HistoryEvent(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)), monitorID: UUID(),
                monitorName: name, url: "https://example.com/\(index)", method: "GET", status: "OK",
                statusCode: 200, durationMs: 100, reason: nil, trigger: .automatic
            )
        }
        store.merge(events, retentionPolicy: .unlimited, maxEvents: 100)

        XCTAssertEqual(store.monitorNames(), ["Alpha", "Zulu"])
    }
}
