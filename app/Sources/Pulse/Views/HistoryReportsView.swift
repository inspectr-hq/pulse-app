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
                    metricCard(title: "Uptime", value: String(format: "%.1f%%", historyVM.uptimePercentage), tint: appVM.settings.statusColorUp.color)
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

                        Chart(historyVM.performanceSamples) { sample in
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
                        .chartLegend(.hidden)
                        .frame(height: 260)
                    }
                }

                GroupBox("Uptime Timeline") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Self.orderedTimelines(
                            historyVM.uptimeTimelines(thresholdMs: appVM.settings.defaultThresholdMs),
                            using: appVM.monitors
                        )) { timeline in
                            let siteStatus = latestStatus(for: timeline.siteName)
                            UptimeTimelineRow(
                                siteName: timeline.siteName,
                                statusIconName: iconName(for: siteStatus),
                                statusIconColor: iconColor(for: siteStatus),
                                uptimePercentage: timeline.uptimePercentage,
                                blocks: timeline.blocks,
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
}

private struct UptimeTimelineRow: View {
    struct BlockSample: Identifiable {
        let id = UUID()
        let index: Int
        let state: HistoryViewModel.UptimeBlockStatus
    }

    let siteName: String
    let statusIconName: String
    let statusIconColor: Color
    let uptimePercentage: Double
    let blocks: [HistoryViewModel.UptimeBlockStatus]
    let rangeStartLabel: String
    let upColor: Color
    let downColor: Color
    let degradedColor: Color
    let noDataColor: Color
    let onSelect: () -> Void

    private var samples: [BlockSample] {
        Array(blocks.enumerated()).map { index, state in
            BlockSample(index: index, state: state)
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Image(systemName: statusIconName)
                        .foregroundStyle(statusIconColor)
                    Text(siteName)
                        .font(.headline)
                    Spacer()
                    Text("\(uptimePercentage, specifier: "%.1f")% uptime")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Chart(samples) { sample in
                    RectangleMark(
                        xStart: .value("Start", Double(sample.index) + 0.08),
                        xEnd: .value("End", Double(sample.index) + 0.92),
                        yStart: .value("Bottom", 0),
                        yEnd: .value("Top", 1)
                    )
                    .foregroundStyle(color(for: sample.state))
                    .clipShape(.rect(cornerRadius: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plot in
                    plot
                        .background(.clear)
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
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .padding(.vertical, 4)
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
}
