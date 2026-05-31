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
                TableColumn("Site") { Text($0.monitorName) }
                    .width(min: 150, ideal: 190)
                TableColumn("Trigger") { Text($0.trigger.rawValue.capitalized) }
                    .width(110)
                TableColumn("Method") { Text($0.method) }
                    .width(90)
                TableColumn("URL") { Text($0.url) }
                TableColumn("Status") { event in
                    Text(event.statusCode.map { "\(event.status) (\($0))" } ?? event.status)
                        .foregroundStyle(statusColor(for: event))
                }
                .width(130)
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
