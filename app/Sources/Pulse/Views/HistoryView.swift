import SwiftUI

struct HistoryView: View {
    @StateObject private var historyVM: HistoryViewModel
    @EnvironmentObject var appVM: AppViewModel

    init(
        selectedName: String? = nil,
        timeFilter: HistoryViewModel.TimeFilter? = nil,
        graphSite: String? = nil,
        graphRange: HistoryViewModel.GraphRange? = nil
    ) {
        let viewModel = HistoryViewModel()
        if let selectedName {
            viewModel.selectedName = selectedName
        }
        if let timeFilter {
            viewModel.timeFilter = timeFilter
        }
        if let graphSite {
            viewModel.graphSite = graphSite
        }
        if let graphRange {
            viewModel.graphRange = graphRange
        }
        self._historyVM = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack {
            HStack {
                Picker("Time", selection: $historyVM.timeFilter) {
                    ForEach(HistoryViewModel.TimeFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 140)
                Picker("Name", selection: $historyVM.selectedName) {
                    ForEach(historyVM.availableNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .frame(width: 170)
                TextField("Search", text: $historyVM.search)
                Button("Export CSV") {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = defaultCSVFileName()
                    if panel.runModal() == .OK, let url = panel.url {
                        try? historyVM.exportCSV().write(to: url, atomically: true, encoding: .utf8)
                    }
                }
                Button("Clear") { historyVM.clear() }
            }
            .padding()

            Table(historyVM.filteredEvents) {
                TableColumn("Timestamp") { Text($0.timestamp.formatted()) }
                    .width(120)
                TableColumn("Site") { Text($0.monitorName) }
                    .width(min: 120, ideal: 180)
                TableColumn("Trigger") { Text($0.trigger.rawValue.capitalized) }
                    .width(70)
                TableColumn("Method") { Text($0.method) }
                    .width(50)
                TableColumn("URL") { Text($0.url) }
                TableColumn("Status") { event in
                    Text(event.statusCode.map { "\(event.status) (\($0))" } ?? event.status)
                        .foregroundStyle(statusColor(for: event))
                }
                .width(80)
                TableColumn("Duration") { Text($0.durationMs.map { "\($0) ms" } ?? "-") }
                TableColumn("") { event in
                    Button {
                        historyVM.delete(eventID: event.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .help("Delete this history item")
                }
                .width(32)
            }
        }
        .onAppear { historyVM.reload() }
    }

    private func statusColor(for event: HistoryEvent) -> Color {
        if event.status == "OK" {
            return appVM.settings.statusColorUp.color
        }
        return appVM.settings.statusColorFailure.color
    }

    private func defaultCSVFileName() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return "pulse-history-\(formatter.string(from: Date())).csv"
    }
}
