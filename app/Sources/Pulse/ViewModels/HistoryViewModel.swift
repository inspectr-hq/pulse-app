import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    enum TimeFilter: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case last1h = "Last 1h"
        case last2h = "Last 2h"
        case last6h = "Last 6h"
        case last12h = "Last 12h"
        case last24h = "Last 24h"
        case last48h = "Last 48h"
        case last3d = "Last 3d"
        case last5d = "Last 5d"
        case last7d = "Last 7d"
        case last14d = "Last 14d"
        case last30d = "Last 30d"
        case last60d = "Last 60d"
        case last90d = "Last 90d"

        var id: String { rawValue }

        var duration: TimeInterval? {
            switch self {
            case .allTime: return nil
            case .last1h: return 3_600
            case .last2h: return 7_200
            case .last6h: return 21_600
            case .last12h: return 43_200
            case .last24h: return 86_400
            case .last48h: return 172_800
            case .last3d: return 259_200
            case .last5d: return 432_000
            case .last7d: return 604_800
            case .last14d: return 1_209_600
            case .last30d: return 2_592_000
            case .last60d: return 5_184_000
            case .last90d: return 7_776_000
            }
        }
    }

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case up = "Up"
        case down = "Down"

        var id: String { rawValue }
    }

    enum GraphRange: String, CaseIterable, Identifiable {
        case last1h = "1h"
        case last2h = "2h"
        case last6h = "6h"
        case last12h = "12h"
        case last24h = "24h"
        case last48h = "48h"
        case last3d = "3d"
        case last5d = "5d"
        case last7d = "7d"
        case last14d = "14d"
        case last30d = "30d"
        case last60d = "60d"
        case last90d = "90d"

        var id: String { rawValue }

        var duration: TimeInterval {
            switch self {
            case .last1h: return 3_600
            case .last2h: return 7_200
            case .last6h: return 21_600
            case .last12h: return 43_200
            case .last24h: return 86_400
            case .last48h: return 172_800
            case .last3d: return 259_200
            case .last5d: return 432_000
            case .last7d: return 604_800
            case .last14d: return 1_209_600
            case .last30d: return 2_592_000
            case .last60d: return 5_184_000
            case .last90d: return 7_776_000
            }
        }
    }

    struct LatencyPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let ms: Int
    }

    struct StatusPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let state: Int
    }

    enum UptimeBlockStatus {
        case up
        case down
        case degraded
        case noData
    }

    struct SiteUptimeTimeline: Identifiable {
        let id = UUID()
        let siteName: String
        let uptimePercentage: Double
        let blocks: [UptimeBlockStatus]
    }

    struct UptimeBucket: Identifiable {
        let id: Int
        let bucketStart: Date
        let bucketEnd: Date
        let status: UptimeBlockStatus
        let sampleCount: Int
        let successCount: Int

        var uptimePercentage: Double {
            guard sampleCount > 0 else { return 0 }
            return (Double(successCount) / Double(sampleCount)) * 100
        }
    }

    struct PerformanceSample: Identifiable {
        let id = UUID()
        let timestamp: Date
        let minMs: Int
        let avgMs: Int
        let maxMs: Int
    }

    struct MetadataMarker: Identifiable {
        let id = UUID()
        let timestamp: Date
        let label: String
        let value: String
    }

    struct TrackingTimelineEntry: Identifiable {
        let id: String
        let firstDetectedAt: Date
        let label: String
        let value: String
    }

    @Published var events: [HistoryEvent] = []
    @Published var search = ""
    @Published var selectedMonitor: UUID?
    @Published var selectedName: String = "All Names"
    @Published var timeFilter: TimeFilter = .allTime
    @Published var statusFilter: StatusFilter = .all
    @Published var graphSite: String = "All Sites"
    @Published var graphRange: GraphRange = .last30d

    private let store: HistoryStoreProtocol

    init(store: HistoryStoreProtocol = HistoryStore()) {
        self.store = store
        reload()
    }

    func reload() {
        // The list, graphs, and analytics query SQLite on demand. Keep this compatibility
        // snapshot empty during normal reloads so opening History does not load the database.
        events = []
    }

    func clear() {
        if hasActiveFilters {
            let filteredIDs = Set(filteredEvents.map(\.id))
            events = store.loadEvents().filter { !filteredIDs.contains($0.id) }
            persistCurrentEvents()
            return
        }

        store.clear()
        reload()
    }

    func delete(eventID: UUID) {
        store.delete(eventID: eventID)
        reload()
    }

    var filteredEvents: [HistoryEvent] {
        store.queryEvents(matching: currentHistoryQuery, order: .descending, limit: nil)
    }

    private var currentHistoryQuery: HistoryQuery {
        let status: HistoryQuery.Status?
        switch statusFilter {
        case .all: status = nil
        case .up: status = .up
        case .down: status = .down
        }

        let since: Date?
        switch timeFilter {
        case .allTime: since = nil
        default: since = Date().addingTimeInterval(-(timeFilter.duration ?? 0))
        }

        return HistoryQuery(
            search: search.isEmpty ? nil : search,
            monitorID: selectedMonitor,
            monitorName: selectedName == "All Names" ? nil : selectedName,
            status: status,
            since: since
        )
    }

    var availableNames: [String] {
        ["All Names"] + store.monitorNames()
    }

    private var hasActiveFilters: Bool {
        !search.isEmpty ||
        selectedMonitor != nil ||
        selectedName != "All Names" ||
        timeFilter != .allTime ||
        statusFilter != .all
    }

    private func persistCurrentEvents() {
        let retained = events.sorted(by: { $0.timestamp < $1.timestamp })
        store.replaceAll(with: retained)
    }

    var availableGraphSites: [String] {
        ["All Sites"] + store.monitorNames()
    }

    var graphEvents: [HistoryEvent] {
        let end = Date()
        return store.queryEvents(matching: graphQuery(referenceDate: end),
            order: .ascending,
            limit: nil
        )
    }

    private func graphQuery(referenceDate: Date = Date()) -> HistoryQuery {
        HistoryQuery(
            monitorName: graphSite == "All Sites" ? nil : graphSite,
            since: referenceDate.addingTimeInterval(-graphRange.duration),
            until: referenceDate
        )
    }

    func graphDateDomain(referenceDate: Date = Date()) -> ClosedRange<Date> {
        let end = referenceDate
        let start = end.addingTimeInterval(-graphRange.duration)
        return start...end
    }

    var latencyPoints: [LatencyPoint] {
        graphEvents.compactMap { event in
            guard let ms = event.durationMs else { return nil }
            return LatencyPoint(timestamp: event.timestamp, ms: ms)
        }
    }

    var statusPoints: [StatusPoint] {
        graphEvents.map { event in
            let isUp = event.status == "OK"
            return StatusPoint(timestamp: event.timestamp, state: isUp ? 1 : 0)
        }
    }

    var uptimePercentage: Double {
        let aggregate = store.aggregate(matching: graphQuery())
        guard aggregate.sampleCount > 0 else { return 0 }
        return (Double(aggregate.successCount) / Double(aggregate.sampleCount)) * 100
    }

    var averageLatencyMs: Int {
        store.aggregate(matching: graphQuery()).averageLatencyMs
    }

    var p95LatencyMs: Int {
        store.percentileLatency(0.95, matching: graphQuery()) ?? 0
    }

    var p99LatencyMs: Int {
        store.percentileLatency(0.99, matching: graphQuery()) ?? 0
    }

    var peakLatencyMs: Int {
        store.aggregate(matching: graphQuery()).peakLatencyMs
    }

    var performanceSamples: [PerformanceSample] {
        let samples = latencyPoints
        guard !samples.isEmpty else { return [] }

        let bucketCount: Int
        switch graphRange {
        case .last1h, .last2h, .last6h, .last12h, .last24h: bucketCount = 36
        case .last48h, .last3d, .last5d, .last7d: bucketCount = 56
        case .last14d, .last30d: bucketCount = 72
        case .last60d, .last90d: bucketCount = 90
        }

        let end = Date()
        let start = end.addingTimeInterval(-graphRange.duration)
        let span = graphRange.duration / Double(bucketCount)
        var buckets = Array(repeating: [Int](), count: bucketCount)

        for point in samples {
            let elapsed = point.timestamp.timeIntervalSince(start)
            let raw = Int(elapsed / span)
            let index = max(0, min(bucketCount - 1, raw))
            buckets[index].append(point.ms)
        }

        return buckets.enumerated().compactMap { index, values in
            guard !values.isEmpty else { return nil }
            let minMs = values.min() ?? 0
            let maxMs = values.max() ?? 0
            let avgMs = values.reduce(0, +) / values.count
            let timestamp = start.addingTimeInterval((Double(index) + 0.5) * span)
            return PerformanceSample(timestamp: timestamp, minMs: minMs, avgMs: avgMs, maxMs: maxMs)
        }
    }

    var metadataMarkers: [MetadataMarker] {
        guard graphSite != "All Sites" else { return [] }

        let cutoff = Date().addingTimeInterval(-graphRange.duration)
        let siteEvents = metadataEvents(for: graphSite, cutoff: cutoff)

        var markers: [MetadataMarker] = []
        var previousValue = siteEvents
            .last(where: { event in
                event.timestamp < cutoff &&
                !(event.metadataValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            })?
            .metadataValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for event in siteEvents where event.timestamp >= cutoff {
            guard let rawValue = event.metadataValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawValue.isEmpty else {
                continue
            }

            guard rawValue != previousValue else {
                continue
            }

            let label = event.metadataLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedLabel = label.flatMap { $0.isEmpty ? nil : $0 } ?? "Tracked Value"
            markers.append(
                MetadataMarker(
                    timestamp: event.timestamp,
                    label: resolvedLabel,
                    value: rawValue
                )
            )
            previousValue = rawValue
        }

        return markers
    }

    private func metadataEvents(for siteName: String, cutoff: Date) -> [HistoryEvent] {
        let predecessor = store.queryEvents(
            matching: HistoryQuery(monitorName: siteName, until: cutoff),
            order: .descending,
            limit: 1
        )
        let rangeEvents = store.queryEvents(
            matching: HistoryQuery(
                monitorName: siteName,
                since: cutoff,
                until: Date()
            ),
            order: .ascending,
            limit: nil
        )
        return (predecessor + rangeEvents).sorted { lhs, rhs in
            lhs.timestamp == rhs.timestamp ? lhs.id.uuidString < rhs.id.uuidString : lhs.timestamp < rhs.timestamp
        }
    }

    var trackingTimelineEntries: [TrackingTimelineEntry] {
        guard graphSite != "All Sites" else { return [] }

        return store.trackingValues(for: graphSite).map {
            TrackingTimelineEntry(
                id: "\($0.label)\t\($0.value)",
                firstDetectedAt: $0.firstDetectedAt,
                label: $0.label,
                value: $0.value
            )
        }
    }

    func uptimeBlocks(thresholdMs: Int) -> [UptimeBlockStatus] {
        uptimeBuckets(thresholdMs: thresholdMs).map(\.status)
    }

    func uptimeTimelines(thresholdMs: Int) -> [SiteUptimeTimeline] {
        let grouped = Dictionary(grouping: graphEvents, by: \.monitorName)
        return grouped.keys.sorted().map { siteName in
            let siteEvents = grouped[siteName] ?? []
            let blocks = uptimeBuckets(from: siteEvents, thresholdMs: thresholdMs, referenceDate: Date()).map(\.status)
            let sampleCount = siteEvents.count
            let upCount = siteEvents.filter { $0.status == "OK" }.count
            let uptime = sampleCount > 0 ? (Double(upCount) / Double(sampleCount)) * 100 : 0
            return SiteUptimeTimeline(siteName: siteName, uptimePercentage: uptime, blocks: blocks)
        }
    }

    func uptimeBuckets(thresholdMs: Int, referenceDate: Date = Date()) -> [UptimeBucket] {
        uptimeBuckets(from: graphEvents, thresholdMs: thresholdMs, referenceDate: referenceDate)
    }

    func uptimeBuckets(
        for siteName: String,
        thresholdMs: Int,
        referenceDate: Date = Date()
    ) -> [UptimeBucket] {
        let siteEvents = store.queryEvents(
            matching: HistoryQuery(
                monitorName: siteName,
                since: referenceDate.addingTimeInterval(-graphRange.duration),
                until: referenceDate
            ),
            order: .ascending,
            limit: nil
        )
        return uptimeBuckets(from: siteEvents, thresholdMs: thresholdMs, referenceDate: referenceDate)
    }

    private func uptimeBuckets(from events: [HistoryEvent], thresholdMs: Int, referenceDate: Date) -> [UptimeBucket] {
        let blockCount: Int
        switch graphRange {
        case .last1h, .last2h, .last6h, .last12h, .last24h: blockCount = 24
        case .last48h, .last3d, .last5d, .last7d: blockCount = 42
        case .last14d, .last30d: blockCount = 60
        case .last60d, .last90d: blockCount = 90
        }

        let timeline = events.sorted(by: { $0.timestamp < $1.timestamp })

        guard !timeline.isEmpty else {
            return (0..<blockCount).map { index in
                let bucketStart = referenceDate.addingTimeInterval(-graphRange.duration + (Double(index) * graphRange.duration / Double(blockCount)))
                let bucketEnd = bucketStart.addingTimeInterval(graphRange.duration / Double(blockCount))
                return UptimeBucket(
                    id: index,
                    bucketStart: bucketStart,
                    bucketEnd: bucketEnd,
                    status: .noData,
                    sampleCount: 0,
                    successCount: 0
                )
            }
        }

        let end = referenceDate
        let start = end.addingTimeInterval(-graphRange.duration)
        let bucketSpan = graphRange.duration / Double(blockCount)

        var buckets: [UptimeBucket] = []
        buckets.reserveCapacity(blockCount)

        for i in 0..<blockCount {
            let bucketStart = start.addingTimeInterval(Double(i) * bucketSpan)
            let bucketEnd = bucketStart.addingTimeInterval(bucketSpan)
            let bucketEvents = timeline.filter { $0.timestamp >= bucketStart && $0.timestamp < bucketEnd }

            if bucketEvents.isEmpty {
                buckets.append(UptimeBucket(id: i, bucketStart: bucketStart, bucketEnd: bucketEnd, status: .noData, sampleCount: 0, successCount: 0))
                continue
            }

            let failures = bucketEvents.filter { $0.status != "OK" }.count
            let successes = bucketEvents.count - failures

            // Downtime means the bucket had no successful checks at all.
            if successes == 0 {
                buckets.append(UptimeBucket(id: i, bucketStart: bucketStart, bucketEnd: bucketEnd, status: .down, sampleCount: bucketEvents.count, successCount: successes))
                continue
            }

            let degraded = failures > 0
            buckets.append(UptimeBucket(id: i, bucketStart: bucketStart, bucketEnd: bucketEnd, status: degraded ? .degraded : .up, sampleCount: bucketEvents.count, successCount: successes))
        }

        return buckets
    }

    func exportCSV() -> String {
        let header = "timestamp,monitor_name,trigger,method,url,status,status_code,duration_ms,reason,metadata_label,metadata_value"
        let rows = filteredEvents.map {
            "\($0.timestamp.ISO8601Format()),\($0.monitorName),\($0.trigger.rawValue),\($0.method),\($0.url),\($0.status),\($0.statusCode.map(String.init) ?? ""),\($0.durationMs.map(String.init) ?? ""),\($0.reason ?? ""),\($0.metadataLabel ?? ""),\($0.metadataValue ?? "")"
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
