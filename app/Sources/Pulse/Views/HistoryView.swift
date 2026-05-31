import SwiftUI

struct HistoryView: View {
    @StateObject private var historyVM = HistoryViewModel()
    @EnvironmentObject var appVM: AppViewModel

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
                    panel.nameFieldStringValue = "pulse-history.csv"
                    if panel.runModal() == .OK, let url = panel.url {
                        try? historyVM.exportCSV().write(to: url, atomically: true, encoding: .utf8)
                    }
                }
                Button("Clear") { historyVM.clear() }
            }
            .padding()

            Table(historyVM.filteredEvents) {
                TableColumn("Timestamp") { Text($0.timestamp.formatted()) }
                TableColumn("Trigger") { Text($0.trigger.rawValue.capitalized) }
                TableColumn("Method") { Text($0.method) }
                TableColumn("URL") { Text($0.url) }
                TableColumn("Status") { event in
                    Text(event.statusCode.map { "\(event.status) (\($0))" } ?? event.status)
                        .foregroundStyle(statusColor(for: event))
                }
                TableColumn("Duration") { Text($0.durationMs.map { "\($0) ms" } ?? "-") }
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
}
