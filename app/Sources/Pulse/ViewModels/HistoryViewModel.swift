import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    enum TimeFilter: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case last24h = "Last 24h"
        case last7d = "Last 7d"

        var id: String { rawValue }
    }

    @Published var events: [HistoryEvent] = []
    @Published var search = ""
    @Published var selectedMonitor: UUID?
    @Published var selectedName: String = "All Names"
    @Published var timeFilter: TimeFilter = .allTime

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
            }
            return bySearch && byMonitor && byName && byTime
        }
    }

    var availableNames: [String] {
        let names = Set(events.map(\.monitorName))
        return ["All Names"] + names.sorted()
    }

    func exportCSV() -> String {
        let header = "timestamp,trigger,method,url,status,status_code,duration_ms,reason"
        let rows = filteredEvents.map {
            "\($0.timestamp.ISO8601Format()),\($0.trigger.rawValue),\($0.method),\($0.url),\($0.status),\($0.statusCode.map(String.init) ?? ""),\($0.durationMs.map(String.init) ?? ""),\($0.reason ?? "")"
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
