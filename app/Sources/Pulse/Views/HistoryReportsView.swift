import SwiftUI
import Charts

struct HistoryReportsView: View {
    @StateObject private var historyVM = HistoryViewModel()
    @EnvironmentObject var appVM: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dashboard")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Picker("Site", selection: $historyVM.graphSite) {
                    ForEach(historyVM.availableGraphSites, id: \.self) { site in
                        Text(site).tag(site)
                    }
                }
                .frame(width: 190)
                Picker("Range", selection: $historyVM.graphRange) {
                    ForEach(HistoryViewModel.GraphRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .frame(width: 100)
                Button("Refresh") { historyVM.reload() }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    metricCard(title: "Uptime", value: formattedPercentage(historyVM.uptimePercentage) + "%", tint: appVM.settings.statusColorUp.color)
                    metricCard(title: "Avg Latency", value: historyVM.averageLatencyMs > 0 ? "\(historyVM.averageLatencyMs) ms" : "-", tint: .secondary)
                    metricCard(title: "P95 Latency", value: historyVM.p95LatencyMs > 0 ? "\(historyVM.p95LatencyMs) ms" : "-", tint: .secondary)
                    metricCard(title: "Samples", value: "\(historyVM.graphEvents.count)", tint: .secondary)
                }

                GroupBox("Performance Trend (ms)") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 0) {
                            compactMetric(title: "HIGHEST", value: historyVM.peakLatencyMs, tint: Color.blue)
                            compactMetric(title: "LOWEST", value: historyVM.performanceSamples.map(\.minMs).min() ?? 0, tint: Color.green)
                            compactMetric(title: "AVERAGE", value: historyVM.averageLatencyMs, tint: Color.purple)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.08))
                        )

                        Chart {
                            ForEach(historyVM.performanceSamples) { sample in
                            AreaMark(
                                x: .value("Time", sample.timestamp),
                                y: .value("Average ms", sample.avgMs)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.28), Color.blue.opacity(0.06)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Time", sample.timestamp),
                                y: .value("Average ms", sample.avgMs)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 2.2))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.blue.opacity(0.9))

                            PointMark(
                                x: .value("Time", sample.timestamp),
                                y: .value("Average ms", sample.avgMs)
                            )
                            .symbolSize(14)
                            .foregroundStyle(Color.blue.opacity(0.85))
                            }

                            if Self.shouldShowMetadataMarkers(for: historyVM.graphSite) {
                                ForEach(historyVM.metadataMarkers) { marker in
                                RuleMark(x: .value("Metadata Change", marker.timestamp))
                                    .foregroundStyle(Color.orange.opacity(0.9))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    .annotation(position: .top, spacing: 6) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(Self.metadataMarkerTitle(for: marker))
                                                .font(.caption.weight(.semibold))
                                            Text(marker.timestamp.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
                                        )
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                                    .foregroundStyle(.quaternary)
                                AxisValueLabel {
                                    if let ms = value.as(Int.self) {
                                        Text("\(ms)ms")
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                                    .foregroundStyle(.quaternary)
                                AxisValueLabel(format: .dateTime.hour().minute())
                            }
                        }
                        .chartXScale(domain: historyVM.graphDateDomain())
                        .chartLegend(.hidden)
                        .frame(height: 260)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Uptime Timeline")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(Self.orderedTimelines(
                            historyVM.uptimeTimelines(thresholdMs: appVM.settings.defaultThresholdMs),
                            using: appVM.monitors
                        ).enumerated()), id: \.element.id) { index, timeline in
                            let siteStatus = latestStatus(for: timeline.siteName)
                            let buckets = historyVM.uptimeBuckets(
                                for: timeline.siteName,
                                thresholdMs: appVM.settings.defaultThresholdMs,
                                referenceDate: Date()
                            )
                            UptimeTimelineRow(
                                rowIndex: index,
                                siteName: timeline.siteName,
                                statusIconName: iconName(for: siteStatus),
                                statusIconColor: iconColor(for: siteStatus),
                                uptimePercentage: timeline.uptimePercentage,
                                buckets: buckets,
                                range: historyVM.graphRange,
                                rangeStartLabel: rangeStartLabel,
                                upColor: appVM.settings.statusColorUp.color,
                                downColor: appVM.settings.statusColorFailure.color,
                                degradedColor: appVM.settings.statusColorSlow.color,
                                noDataColor: appVM.settings.statusColorOffline.color.opacity(0.35)
                            ) {
                                WindowManager.shared.showHistory(
                                    appVM: appVM,
                                    selectedName: timeline.siteName,
                                    timeFilter: historyTimeFilter(for: historyVM.graphRange),
                                    graphSite: timeline.siteName,
                                    graphRange: historyVM.graphRange
                                )
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .onAppear { historyVM.reload() }
    }

    static func orderedTimelines(
        _ timelines: [HistoryViewModel.SiteUptimeTimeline],
        using monitors: [SiteMonitor]
    ) -> [HistoryViewModel.SiteUptimeTimeline] {
        let orderLookup = Dictionary(uniqueKeysWithValues: monitors.enumerated().map { ($1.nameOrHost, $0) })
        return timelines.sorted { lhs, rhs in
            let leftIndex = orderLookup[lhs.siteName] ?? Int.max
            let rightIndex = orderLookup[rhs.siteName] ?? Int.max
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
            return lhs.siteName.localizedCaseInsensitiveCompare(rhs.siteName) == .orderedAscending
        }
    }

    private func latestStatus(for siteName: String) -> SiteStatus {
        guard let monitor = appVM.monitors.first(where: { $0.nameOrHost == siteName }) else {
            return .unknown
        }
        if !monitor.isEnabled {
            return .paused
        }
        return appVM.statuses[monitor.id] ?? .unknown
    }

    private func iconName(for status: SiteStatus) -> String {
        switch status {
        case .up:
            return "checkmark.circle.fill"
        case .down:
            return "xmark.octagon.fill"
        case .checking:
            return "clock.fill"
        case .paused:
            return "pause.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private func iconColor(for status: SiteStatus) -> Color {
        switch status {
        case .up:
            return appVM.settings.statusColorUp.color
        case .down:
            return appVM.settings.statusColorFailure.color
        case .checking:
            return appVM.settings.statusColorSlow.color
        case .paused:
            return appVM.settings.statusColorOffline.color
        case .unknown:
            return appVM.settings.statusColorOffline.color.opacity(0.7)
        }
    }

    private func metricCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func compactMetric(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                Text("\(value)ms")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangeStartLabel: String {
        switch historyVM.graphRange {
        case .last24h: return "24h ago"
        case .last7d: return "7d ago"
        case .last30d: return "30d ago"
        case .last90d: return "90d ago"
        }
    }

    private func historyTimeFilter(for range: HistoryViewModel.GraphRange) -> HistoryViewModel.TimeFilter {
        switch range {
        case .last24h: return .last24h
        case .last7d: return .last7d
        case .last30d: return .last30d
        case .last90d: return .last90d
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func tooltipShouldRenderBelow(rowIndex: Int) -> Bool {
        rowIndex == 0
    }

    static func shouldShowMetadataMarkers(for graphSite: String) -> Bool {
        graphSite != "All Sites"
    }

    static func metadataMarkerTitle(for marker: HistoryViewModel.MetadataMarker) -> String {
        "\(marker.label) \(marker.value)"
    }
}

private struct UptimeTimelineRow: View {
    let rowIndex: Int
    let siteName: String
    let statusIconName: String
    let statusIconColor: Color
    let uptimePercentage: Double
    let buckets: [HistoryViewModel.UptimeBucket]
    let range: HistoryViewModel.GraphRange
    let rangeStartLabel: String
    let upColor: Color
    let downColor: Color
    let degradedColor: Color
    let noDataColor: Color
    let onSelect: () -> Void

    @State private var hoveredBucketID: Int?

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Image(systemName: statusIconName)
                        .foregroundStyle(statusIconColor)
                    Text(siteName)
                        .font(.headline)
                    Spacer()
                    Text("\(formattedUptimePercentage(uptimePercentage))%")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                GeometryReader { proxy in
                    let spacing: CGFloat = 3
                    let count = max(buckets.count, 1)
                    let totalSpacing = spacing * CGFloat(max(count - 1, 0))
                    let availableWidth = max(proxy.size.width, 0)
                    let barWidth = max(4, (availableWidth - totalSpacing) / CGFloat(count))
                    let tooltipWidth: CGFloat = 192
                    let tooltipHeight: CGFloat = 72
                    let hoveredBucket = hoveredBucketID.flatMap { id in buckets.first(where: { $0.id == id }) }
                    let tooltipBelow = HistoryReportsView.tooltipShouldRenderBelow(rowIndex: rowIndex)
                    let tooltipX = hoveredBucket.map {
                        tooltipOffsetX(
                            bucketID: $0.id,
                            availableWidth: availableWidth,
                            barWidth: barWidth,
                            spacing: spacing,
                            tooltipWidth: tooltipWidth
                        )
                    }

                    ZStack(alignment: .topLeading) {
                        HStack(alignment: .center, spacing: spacing) {
                            ForEach(buckets) { bucket in
                                let isHovered = hoveredBucketID == bucket.id
                                Rectangle()
                                    .fill(color(for: bucket.status))
                                    .frame(width: barWidth, height: 28)
                                    .clipShape(.rect(cornerRadius: 2))
                                    .overlay {
                                        if isHovered {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.25))
                                        }
                                    }
                                    .onHover { isHovering in
                                        if isHovering {
                                            hoveredBucketID = bucket.id
                                        } else if hoveredBucketID == bucket.id {
                                            hoveredBucketID = nil
                                        }
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let hoveredBucket, let tooltipX {
                            tooltipCard(for: hoveredBucket)
                                .frame(width: tooltipWidth, alignment: .leading)
                                .offset(x: tooltipX, y: tooltipYOffset(isBelowTopRow: tooltipBelow, tooltipHeight: tooltipHeight))
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 28, alignment: .topLeading)
                }
                .frame(height: 28)
                .accessibilityLabel("\(siteName) uptime timeline")

                HStack {
                    Text(rangeStartLabel)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Spacer()
                    Text("Today")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tooltipOffsetX(
        bucketID: Int,
        availableWidth: CGFloat,
        barWidth: CGFloat,
        spacing: CGFloat,
        tooltipWidth: CGFloat
    ) -> CGFloat {
        let barCenter = CGFloat(bucketID) * (barWidth + spacing) + (barWidth / 2)
        let unclamped = barCenter - (tooltipWidth / 2)
        return min(max(0, unclamped), max(0, availableWidth - tooltipWidth))
    }

    private func tooltipCard(for bucket: HistoryViewModel.UptimeBucket) -> some View {
        let status = bucket.status
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: status))
                    .foregroundStyle(color(for: status))
                Text("\(title(for: status)) - \(formattedUptimePercentage(bucket.uptimePercentage))%")
                    .font(.headline)
                Spacer()
            }

            Text(bucketPeriodLabel(bucket, range: range))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
        )
    }

    private func tooltipYOffset(isBelowTopRow: Bool, tooltipHeight: CGFloat) -> CGFloat {
        isBelowTopRow ? 30 : -(tooltipHeight + 4)
    }

    private func bucketPeriodLabel(_ bucket: HistoryViewModel.UptimeBucket, range: HistoryViewModel.GraphRange) -> String {
        let formatter = DateFormatter()
        switch range {
        case .last24h:
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        case .last7d, .last30d, .last90d:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter.string(from: bucket.bucketStart)
    }

    private func title(for status: HistoryViewModel.UptimeBlockStatus) -> String {
        switch status {
        case .up: return "Up"
        case .down: return "Downtime"
        case .degraded: return "Degraded"
        case .noData: return "No Data"
        }
    }

    private func iconName(for status: HistoryViewModel.UptimeBlockStatus) -> String {
        switch status {
        case .up: return "checkmark.circle.fill"
        case .down: return "xmark.octagon.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .noData: return "questionmark.circle.fill"
        }
    }

    private func color(for status: HistoryViewModel.UptimeBlockStatus) -> Color {
        switch status {
        case .up:
            return upColor
        case .down:
            return downColor
        case .degraded:
            return degradedColor
        case .noData:
            return noDataColor
        }
    }

    private func formattedUptimePercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
