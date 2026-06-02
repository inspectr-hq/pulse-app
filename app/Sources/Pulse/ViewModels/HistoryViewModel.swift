import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    enum TimeFilter: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case last24h = "Last 24h"
        case last7d = "Last 7d"
        case last30d = "Last 30d"
        case last90d = "Last 90d"

        var id: String { rawValue }
    }

    enum GraphRange: String, CaseIterable, Identifiable {
        case last24h = "24h"
        case last7d = "7d"
        case last30d = "30d"
        case last90d = "90d"

        var id: String { rawValue }

        var duration: TimeInterval {
            switch self {
            case .last24h: return 86_400
            case .last7d: return 604_800
            case .last30d: return 2_592_000
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

    @Published var events: [HistoryEvent] = []
    @Published var search = ""
    @Published var selectedMonitor: UUID?
    @Published var selectedName: String = "All Names"
    @Published var timeFilter: TimeFilter = .allTime
    @Published var graphSite: String = "All Sites"
    @Published var graphRange: GraphRange = .last30d

    private let store: HistoryStoreProtocol

    init(store: HistoryStoreProtocol = HistoryStore()) {
        self.store = store
        reload()
    }

    func reload() {
        events = store.loadEvents().sorted(by: { $0.timestamp > $1.timestamp })
    }

    func clear() {
        store.clear()
        reload()
    }

    func delete(eventID: UUID) {
        store.delete(eventID: eventID)
        reload()
    }

    var filteredEvents: [HistoryEvent] {
        let now = Date()
        return events.filter { event in
            let bySearch = search.isEmpty || event.url.localizedCaseInsensitiveContains(search) || event.monitorName.localizedCaseInsensitiveContains(search)
            let byMonitor = selectedMonitor == nil || event.monitorID == selectedMonitor
            let byName = selectedName == "All Names" || event.monitorName == selectedName
            let byTime: Bool
            switch timeFilter {
            case .allTime: byTime = true
            case .last24h: byTime = event.timestamp >= now.addingTimeInterval(-86400)
            case .last7d: byTime = event.timestamp >= now.addingTimeInterval(-604800)
            case .last30d: byTime = event.timestamp >= now.addingTimeInterval(-2592000)
            case .last90d: byTime = event.timestamp >= now.addingTimeInterval(-7776000)
            }
            return bySearch && byMonitor && byName && byTime
        }
    }

    var availableNames: [String] {
        let names = Set(events.map(\.monitorName))
        return ["All Names"] + names.sorted()
    }

    var availableGraphSites: [String] {
        let names = Set(events.map(\.monitorName))
        return ["All Sites"] + names.sorted()
    }

    var graphEvents: [HistoryEvent] {
        let cutoff = Date().addingTimeInterval(-graphRange.duration)
        return events
            .filter { event in
                event.timestamp >= cutoff &&
                (graphSite == "All Sites" || event.monitorName == graphSite)
            }
            .sorted(by: { $0.timestamp < $1.timestamp })
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
        let points = statusPoints
        guard !points.isEmpty else { return 0 }
        let up = points.filter { $0.state == 1 }.count
        return (Double(up) / Double(points.count)) * 100
    }

    var averageLatencyMs: Int {
        let values = latencyPoints.map(\.ms)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    var p95LatencyMs: Int {
        let values = latencyPoints.map(\.ms).sorted()
        guard !values.isEmpty else { return 0 }
        let idx = min(values.count - 1, Int(Double(values.count) * 0.95))
        return values[idx]
    }

    var peakLatencyMs: Int {
        latencyPoints.map(\.ms).max() ?? 0
    }

    var performanceSamples: [PerformanceSample] {
        let samples = latencyPoints
        guard !samples.isEmpty else { return [] }

        let bucketCount: Int
        switch graphRange {
        case .last24h: bucketCount = 36
        case .last7d: bucketCount = 56
        case .last30d: bucketCount = 72
        case .last90d: bucketCount = 90
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
        let siteEvents = events.filter { $0.monitorName == siteName }
        return uptimeBuckets(from: siteEvents, thresholdMs: thresholdMs, referenceDate: referenceDate)
    }

    private func uptimeBuckets(from events: [HistoryEvent], thresholdMs: Int, referenceDate: Date) -> [UptimeBucket] {
        let blockCount: Int
        switch graphRange {
        case .last24h: blockCount = 24
        case .last7d: blockCount = 42
        case .last30d: blockCount = 60
        case .last90d: blockCount = 90
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
        let header = "timestamp,monitor_name,trigger,method,url,status,status_code,duration_ms,reason"
        let rows = filteredEvents.map {
            "\($0.timestamp.ISO8601Format()),\($0.monitorName),\($0.trigger.rawValue),\($0.method),\($0.url),\($0.status),\($0.statusCode.map(String.init) ?? ""),\($0.durationMs.map(String.init) ?? ""),\($0.reason ?? "")"
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
