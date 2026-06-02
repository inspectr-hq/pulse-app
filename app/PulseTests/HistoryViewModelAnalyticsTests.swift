import XCTest
@testable import Pulse

@MainActor
final class HistoryViewModelAnalyticsTests: XCTestCase {
    func testUptimeTimelinesGroupPerSiteAndClassifyStates() {
        let now = Date()
        let siteA = UUID()
        let siteB = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now.addingTimeInterval(-20 * 60), monitorID: siteA, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-10 * 60), monitorID: siteA, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "Down", statusCode: nil, durationMs: 80, reason: "timeout", trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-15 * 60), monitorID: siteB, monitorName: "Site B", url: "https://b.dev", method: "GET", status: "Down", statusCode: nil, durationMs: 90, reason: "timeout", trigger: .automatic)
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphRange = .last24h
        let timelines = vm.uptimeTimelines(thresholdMs: 2_000)

        XCTAssertEqual(timelines.count, 2)
        let a = try? XCTUnwrap(timelines.first { $0.siteName == "Site A" })
        let b = try? XCTUnwrap(timelines.first { $0.siteName == "Site B" })
        guard let a, let b else {
            XCTFail("Expected Site A and Site B timelines")
            return
        }
        XCTAssertEqual(a.blocks.count, 24)
        XCTAssertEqual(b.blocks.count, 24)
        XCTAssertEqual(a.uptimePercentage, 50, accuracy: 0.001)
        XCTAssertEqual(b.uptimePercentage, 0, accuracy: 0.001)
        XCTAssertTrue(a.blocks.contains(.degraded))
        XCTAssertTrue(b.blocks.contains(.down))
        XCTAssertGreaterThan(a.blocks.filter { $0 == .noData }.count, 0)
    }

    func testPerformanceSamplesProduceValidMinAvgMax() {
        let now = Date()
        let monitor = UUID()
        let latencies = [100, 200, 500, 80, 1200, 300]
        let events = latencies.enumerated().map { idx, ms in
            HistoryEvent(
                timestamp: now.addingTimeInterval(TimeInterval(-idx * 60)),
                monitorID: monitor,
                monitorName: "Site A",
                url: "https://a.dev",
                method: "GET",
                status: "OK",
                statusCode: 200,
                durationMs: ms,
                reason: nil,
                trigger: .automatic
            )
        }

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphRange = .last24h
        let samples = vm.performanceSamples

        XCTAssertFalse(samples.isEmpty)
        for sample in samples {
            XCTAssertLessThanOrEqual(sample.minMs, sample.avgMs)
            XCTAssertLessThanOrEqual(sample.avgMs, sample.maxMs)
        }
    }

    func testUptimeBucketsExposePeriodAndUptimePercentage() {
        let referenceDate = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(
                timestamp: referenceDate.addingTimeInterval(-3 * 3_600 - 900),
                monitorID: monitor,
                monitorName: "Site A",
                url: "https://a.dev",
                method: "GET",
                status: "OK",
                statusCode: 200,
                durationMs: 120,
                reason: nil,
                trigger: .automatic
            ),
            HistoryEvent(
                timestamp: referenceDate.addingTimeInterval(-3 * 3_600 - 300),
                monitorID: monitor,
                monitorName: "Site A",
                url: "https://a.dev",
                method: "GET",
                status: "Down",
                statusCode: nil,
                durationMs: 90,
                reason: "timeout",
                trigger: .automatic
            )
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphRange = .last24h
        let buckets = vm.uptimeBuckets(thresholdMs: 2_000, referenceDate: referenceDate)

        let bucket = try? XCTUnwrap(buckets.first { $0.sampleCount == 2 })
        guard let bucket else {
            XCTFail("Expected one bucket with two samples")
            return
        }

        XCTAssertEqual(buckets.count, 24)
        XCTAssertEqual(bucket.status, .degraded)
        XCTAssertEqual(bucket.uptimePercentage, 50, accuracy: 0.001)
        XCTAssertEqual(bucket.bucketEnd.timeIntervalSince(bucket.bucketStart), 3600, accuracy: 0.001)
    }
}

private final class StubHistoryStore: HistoryStoreProtocol {
    private var events: [HistoryEvent]

    init(events: [HistoryEvent]) {
        self.events = events
    }

    func loadEvents() -> [HistoryEvent] { events }

    func append(_ event: HistoryEvent, retentionPolicy: HistoryRetentionPolicy, maxEvents: Int) {
        events.append(event)
    }

    func delete(eventID: UUID) {
        events.removeAll { $0.id == eventID }
    }

    func clear() {
        events = []
    }
}
