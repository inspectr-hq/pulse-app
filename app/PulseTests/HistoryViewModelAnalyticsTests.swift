import XCTest
@testable import Pulse

@MainActor
final class HistoryViewModelAnalyticsTests: XCTestCase {
    func testDashboardDefaultsToLast30Days() {
        let vm = HistoryViewModel(store: StubHistoryStore(events: []))

        XCTAssertEqual(vm.graphRange, .last30d)
    }

    func testTimeRangesExposeGranularDurations() {
        XCTAssertEqual(HistoryViewModel.TimeFilter.last1h.duration, 3_600)
        XCTAssertEqual(HistoryViewModel.TimeFilter.last2h.duration, 7_200)
        XCTAssertEqual(HistoryViewModel.TimeFilter.last6h.duration, 21_600)
        XCTAssertEqual(HistoryViewModel.TimeFilter.last12h.duration, 43_200)
        XCTAssertEqual(HistoryViewModel.TimeFilter.last48h.duration, 172_800)
        XCTAssertEqual(HistoryViewModel.TimeFilter.last3d.duration, 259_200)
        XCTAssertEqual(HistoryViewModel.TimeFilter.last5d.duration, 432_000)
        XCTAssertEqual(HistoryViewModel.TimeFilter.last14d.duration, 1_209_600)
        XCTAssertEqual(HistoryViewModel.TimeFilter.last60d.duration, 5_184_000)
    }

    func testUptimeTimelineUsesPredictableBucketGranularity() {
        XCTAssertEqual(HistoryViewModel.uptimeTimelineGranularity(for: .last24h), .hour)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineGranularity(for: .last48h), .sixHours)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineGranularity(for: .last3d), .sixHours)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineGranularity(for: .last7d), .sixHours)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineGranularity(for: .last14d), .day)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineGranularity(for: .last90d), .day)
    }

    func testUptimeTimelineUsesExpectedNumberOfBuckets() {
        XCTAssertEqual(HistoryViewModel.uptimeTimelineBucketCount(for: .last24h), 24)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineBucketCount(for: .last48h), 8)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineBucketCount(for: .last3d), 12)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineBucketCount(for: .last7d), 28)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineBucketCount(for: .last14d), 14)
        XCTAssertEqual(HistoryViewModel.uptimeTimelineBucketCount(for: .last30d), 30)
    }

    func testFilteredEventsCanBeLimitedToLastHour() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now.addingTimeInterval(-30 * 60), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/recent", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-90 * 60), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/old", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic)
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.timeFilter = .last1h

        XCTAssertEqual(vm.filteredEvents.map(\.url), ["https://a.dev/recent"])
    }

    func testFilteredEventsCanBeLimitedToUpStatus() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: monitor, monitorName: "Site A", url: "https://a.dev/up", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-60), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/down", method: "GET", status: "Down", statusCode: nil, durationMs: 90, reason: "timeout", trigger: .automatic)
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.statusFilter = .up

        XCTAssertEqual(vm.filteredEvents.map(\.status), ["OK"])
    }

    func testFilteredEventsCanBeLimitedToDownStatusAndCombinedWithSearch() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: monitor, monitorName: "Site A", url: "https://a.dev/up", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-60), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/outage", method: "GET", status: "Down", statusCode: nil, durationMs: 90, reason: "timeout", trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-120), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/degraded", method: "GET", status: "Timeout", statusCode: nil, durationMs: 3000, reason: "slow", trigger: .automatic)
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.statusFilter = .down
        vm.search = "outage"

        let filtered = vm.filteredEvents
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.status, "Down")
        XCTAssertEqual(filtered.first?.url, "https://a.dev/outage")
    }

    func testSearchMatchesTrackedValue() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.6.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-60), monitorID: monitor, monitorName: "Site B", url: "https://b.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 90, reason: nil, trigger: .automatic, metadataLabel: "Build", metadataValue: "abc123")
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.search = "2.6"

        XCTAssertEqual(vm.filteredEvents.map(\.monitorName), ["Site A"])
    }

    func testSearchMatchesTrackedValueLabel() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.6.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-60), monitorID: monitor, monitorName: "Site B", url: "https://b.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 90, reason: nil, trigger: .automatic, metadataLabel: "Build", metadataValue: "abc123")
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.search = "build"

        XCTAssertEqual(vm.filteredEvents.map(\.monitorName), ["Site B"])
    }

    func testClearDeletesOnlyFilteredEventsWhenFiltersAreActive() {
        let now = Date()
        let firstMonitor = UUID()
        let secondMonitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: firstMonitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-60), monitorID: secondMonitor, monitorName: "Site B", url: "https://b.dev", method: "GET", status: "Down", statusCode: nil, durationMs: 90, reason: "timeout", trigger: .automatic)
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.statusFilter = .down

        vm.clear()

        XCTAssertEqual(vm.events.count, 1)
        XCTAssertEqual(vm.events.first?.status, "OK")
        XCTAssertEqual(vm.filteredEvents.count, 0)
    }

    func testClearWithFiltersPersistsRetainedEventsInSingleWrite() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: monitor, monitorName: "Site A", url: "https://a.dev/up", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-60), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/down", method: "GET", status: "Down", statusCode: nil, durationMs: 90, reason: "timeout", trigger: .automatic)
        ]
        let store = RecordingHistoryStore(events: events)
        let vm = HistoryViewModel(store: store)
        vm.statusFilter = .down

        vm.clear()

        XCTAssertEqual(store.replaceAllCalls, 1)
        XCTAssertEqual(store.clearedCalls, 0)
        XCTAssertEqual(store.events.map(\.status), ["OK"])
    }

    func testClearDeletesAllEventsWhenNoFiltersAreActive() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: monitor, monitorName: "Site A", url: "https://a.dev/1", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-60), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/2", method: "GET", status: "Down", statusCode: nil, durationMs: 90, reason: "timeout", trigger: .automatic)
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))

        vm.clear()

        XCTAssertTrue(vm.events.isEmpty)
        XCTAssertTrue(vm.filteredEvents.isEmpty)
    }

    func testStatusFilterCombinesWithSelectedName() {
        let now = Date()
        let firstMonitor = UUID()
        let secondMonitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: firstMonitor, monitorName: "Site A", url: "https://a.dev/up", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-60), monitorID: firstMonitor, monitorName: "Site A", url: "https://a.dev/down", method: "GET", status: "Down", statusCode: nil, durationMs: 90, reason: "timeout", trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-120), monitorID: secondMonitor, monitorName: "Site B", url: "https://b.dev/down", method: "GET", status: "Down", statusCode: nil, durationMs: 95, reason: "timeout", trigger: .automatic)
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.selectedName = "Site A"
        vm.statusFilter = .down

        let filtered = vm.filteredEvents
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.monitorName, "Site A")
        XCTAssertEqual(filtered.first?.status, "Down")
    }

    func testStatusFilterCombinesWithTimeFilter() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now.addingTimeInterval(-2 * 3_600), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/recent-down", method: "GET", status: "Down", statusCode: nil, durationMs: 90, reason: "timeout", trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-26 * 3_600), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/old-down", method: "GET", status: "Down", statusCode: nil, durationMs: 95, reason: "timeout", trigger: .automatic),
            HistoryEvent(timestamp: now.addingTimeInterval(-1_800), monitorID: monitor, monitorName: "Site A", url: "https://a.dev/recent-up", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic)
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.timeFilter = .last24h
        vm.statusFilter = .down

        let filtered = vm.filteredEvents
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.url, "https://a.dev/recent-down")
    }

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

    func testLatencyPercentilesUseSortedLatencyPoints() {
        let now = Date()
        let monitor = UUID()
        let latencies = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
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

        XCTAssertEqual(vm.p95LatencyMs, 1000)
        XCTAssertEqual(vm.p99LatencyMs, 1000)
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

    func testUptimeBucketsCanBeScopedToASingleSite() {
        let referenceDate = Date()
        let siteA = UUID()
        let siteB = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(
                timestamp: referenceDate.addingTimeInterval(-3_600),
                monitorID: siteA,
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
                timestamp: referenceDate.addingTimeInterval(-1_800),
                monitorID: siteB,
                monitorName: "Site B",
                url: "https://b.dev",
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

        let siteABuckets = vm.uptimeBuckets(for: "Site A", thresholdMs: 2_000, referenceDate: referenceDate)
        let siteBBuckets = vm.uptimeBuckets(for: "Site B", thresholdMs: 2_000, referenceDate: referenceDate)

        XCTAssertEqual(siteABuckets.first(where: { $0.sampleCount > 0 })?.status, .up)
        XCTAssertEqual(siteBBuckets.first(where: { $0.sampleCount > 0 })?.status, .down)
        XCTAssertFalse(siteABuckets.contains(where: { $0.status == .degraded }))
    }

    func testMetadataMarkersEmitOnlyOnValueTransitions() throws {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now.addingTimeInterval(-300), monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.5.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-240), monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 118, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.5.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-180), monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 115, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.6.0")
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphRange = .last24h
        vm.graphSite = "Site A"

        XCTAssertEqual(vm.metadataMarkers.count, 2)
        XCTAssertEqual(vm.metadataMarkers.map(\.value), ["2.5.0", "2.6.0"])
        XCTAssertEqual(vm.metadataMarkers.map(\.label), ["Version", "Version"])
    }

    func testMetadataMarkersIgnoreNilAndEmptyValues() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now.addingTimeInterval(-300), monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic, metadataLabel: nil, metadataValue: nil),
            HistoryEvent(timestamp: now.addingTimeInterval(-240), monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 118, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.5.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-180), monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 115, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: ""),
            HistoryEvent(timestamp: now.addingTimeInterval(-120), monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 110, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.6.0")
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphRange = .last24h
        vm.graphSite = "Site A"

        XCTAssertEqual(vm.metadataMarkers.map(\.value), ["2.5.0", "2.6.0"])
    }

    func testMetadataMarkersRespectGraphSiteFilter() {
        let now = Date()
        let siteA = UUID()
        let siteB = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now.addingTimeInterval(-300), monitorID: siteA, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.5.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-180), monitorID: siteB, monitorName: "Site B", url: "https://b.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 115, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "9.9.9")
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphRange = .last24h
        vm.graphSite = "Site B"

        XCTAssertEqual(vm.metadataMarkers.count, 1)
        XCTAssertEqual(vm.metadataMarkers.first?.value, "9.9.9")
    }

    func testMetadataMarkersAreHiddenForAllSitesSelection() {
        let now = Date()
        let siteA = UUID()
        let siteB = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now.addingTimeInterval(-300), monitorID: siteA, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "2.5.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-180), monitorID: siteB, monitorName: "Site B", url: "https://b.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 115, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "9.9.9")
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphRange = .last24h
        vm.graphSite = "All Sites"

        XCTAssertTrue(vm.metadataMarkers.isEmpty)
    }

    func testMetadataMarkersDoNotInventTransitionAtStartOfSelectedRange() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(
                timestamp: now.addingTimeInterval(-8 * 86_400),
                monitorID: monitor,
                monitorName: "Site A",
                url: "https://a.dev",
                method: "GET",
                status: "OK",
                statusCode: 200,
                durationMs: 120,
                reason: nil,
                trigger: .automatic,
                metadataLabel: "Version",
                metadataValue: "0.5.4"
            ),
            HistoryEvent(
                timestamp: now.addingTimeInterval(-6 * 86_400),
                monitorID: monitor,
                monitorName: "Site A",
                url: "https://a.dev",
                method: "GET",
                status: "OK",
                statusCode: 200,
                durationMs: 118,
                reason: nil,
                trigger: .automatic,
                metadataLabel: "Version",
                metadataValue: "0.5.4"
            ),
            HistoryEvent(
                timestamp: now.addingTimeInterval(-1 * 86_400),
                monitorID: monitor,
                monitorName: "Site A",
                url: "https://a.dev",
                method: "GET",
                status: "OK",
                statusCode: 200,
                durationMs: 115,
                reason: nil,
                trigger: .automatic,
                metadataLabel: "Version",
                metadataValue: "0.5.5"
            )
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphRange = .last7d
        vm.graphSite = "Site A"

        XCTAssertEqual(vm.metadataMarkers.map(\.value), ["0.5.5"])
    }

    func testTrackingTimelineShowsNewestFirstDetectionPerTrackedValueForSelectedSite() {
        let now = Date()
        let siteA = UUID()
        let siteB = UUID()
        let firstVersionTime = now.addingTimeInterval(-4 * 86_400)
        let secondVersionTime = now.addingTimeInterval(-2 * 86_400)
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: firstVersionTime, monitorID: siteA, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "1.0.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-3 * 86_400), monitorID: siteA, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 118, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "1.0.0"),
            HistoryEvent(timestamp: secondVersionTime, monitorID: siteA, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 115, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "1.1.0"),
            HistoryEvent(timestamp: now.addingTimeInterval(-1 * 86_400), monitorID: siteB, monitorName: "Site B", url: "https://b.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 110, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "9.9.9")
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphSite = "Site A"

        XCTAssertEqual(vm.trackingTimelineEntries.map(\.value), ["1.1.0", "1.0.0"])
        XCTAssertEqual(vm.trackingTimelineEntries.map(\.label), ["Version", "Version"])
        XCTAssertEqual(vm.trackingTimelineEntries.map(\.firstDetectedAt), [secondVersionTime, firstVersionTime])
    }

    func testTrackingTimelineHiddenForAllSitesSelection() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(timestamp: now, monitorID: monitor, monitorName: "Site A", url: "https://a.dev", method: "GET", status: "OK", statusCode: 200, durationMs: 120, reason: nil, trigger: .automatic, metadataLabel: "Version", metadataValue: "1.0.0")
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        vm.graphSite = "All Sites"

        XCTAssertTrue(vm.trackingTimelineEntries.isEmpty)
    }

    func testExportCSVIncludesMetadataLabelAndValueColumns() {
        let now = Date()
        let monitor = UUID()
        let events: [HistoryEvent] = [
            HistoryEvent(
                timestamp: now,
                monitorID: monitor,
                monitorName: "Site A",
                url: "https://a.dev",
                method: "GET",
                status: "OK",
                statusCode: 200,
                durationMs: 120,
                reason: nil,
                trigger: .automatic,
                metadataLabel: "Version",
                metadataValue: "2.6.0"
            )
        ]

        let vm = HistoryViewModel(store: StubHistoryStore(events: events))
        let csv = vm.exportCSV()

        XCTAssertTrue(csv.contains("metadata_label,metadata_value"))
        XCTAssertTrue(csv.contains("Version,2.6.0"))
    }

    func testGraphDateDomainMatchesSelectedRange() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = HistoryViewModel(store: StubHistoryStore(events: []))
        vm.graphRange = .last24h

        let domain = vm.graphDateDomain(referenceDate: referenceDate)

        XCTAssertEqual(domain.lowerBound, referenceDate.addingTimeInterval(-86_400))
        XCTAssertEqual(domain.upperBound, referenceDate)
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

    func merge(_ events: [HistoryEvent], retentionPolicy: HistoryRetentionPolicy, maxEvents: Int) {
        self.events.append(contentsOf: events)
    }

    func replaceAll(with events: [HistoryEvent]) {
        self.events = events
    }

    func delete(eventID: UUID) {
        events.removeAll { $0.id == eventID }
    }

    func clear() {
        events = []
    }
}

private final class RecordingHistoryStore: HistoryStoreProtocol {
    private(set) var events: [HistoryEvent]
    private(set) var replaceAllCalls = 0
    private(set) var clearedCalls = 0

    init(events: [HistoryEvent]) {
        self.events = events
    }

    func loadEvents() -> [HistoryEvent] { events }

    func append(_ event: HistoryEvent, retentionPolicy: HistoryRetentionPolicy, maxEvents: Int) {
        events.append(event)
    }

    func merge(_ events: [HistoryEvent], retentionPolicy: HistoryRetentionPolicy, maxEvents: Int) {
        self.events.append(contentsOf: events)
    }

    func replaceAll(with events: [HistoryEvent]) {
        replaceAllCalls += 1
        self.events = events
    }

    func delete(eventID: UUID) {
        events.removeAll { $0.id == eventID }
    }

    func clear() {
        clearedCalls += 1
        events = []
    }
}
