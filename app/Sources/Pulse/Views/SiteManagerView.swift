import SwiftUI

struct SiteManagerView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showAdd = false
    @State private var editing: WebsiteMonitor?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Site Manager")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(summaryLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { showAdd = true }) { Image(systemName: "plus") }
                Button(action: { Task { await vm.checkAll(autoOnly: false) } }) { Image(systemName: "arrow.clockwise") }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()

            Table(vm.monitors) {
                TableColumn("Active") { monitor in
                    Toggle("", isOn: Binding(get: { monitor.isEnabled }, set: { vm.setEnabled($0, for: monitor.id) }))
                }
                .width(min: 40, ideal: 44, max: 56)
                TableColumn("Status") { monitor in
                    Circle()
                        .fill(statusColor(for: vm.statuses[monitor.id] ?? .unknown))
                        .frame(width: 11, height: 11)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .width(min: 40, ideal: 44, max: 44)
                TableColumn("Time") { monitor in
                    Text(timeLabel(for: vm.statuses[monitor.id] ?? .unknown))
                        .foregroundStyle(.secondary)
                }
                .width(min: 52, ideal: 64, max: 120)
                TableColumn("Name") { monitor in
                    Text(monitor.nameOrHost)
                        .lineLimit(1)
                }
                .width(min: 140, ideal: 180, max: 280)
                TableColumn("URL") { monitor in
                    Text(monitor.url.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .width(min: 200, ideal: 240, max: 400)
                TableColumn("Method") { monitor in
                    Text(monitor.method.rawValue)
                        .foregroundStyle(.secondary)
                }
                .width(min: 48, ideal: 52, max: 64)
                TableColumn("Actions") { monitor in
                    HStack(spacing: 10) {
                        Button("Edit") { editing = monitor }
                        Button("Remove") { vm.removeMonitor(id: monitor.id) }
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .width(min: 130, ideal: 150, max: 170)
            }
            .alternatingRowBackgrounds(.disabled)
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .sheet(item: $editing) { item in
                MonitorFormView(mode: .edit, monitor: item) { draft, rawURL in
                    guard let normalizedURL = URLInput.normalize(rawURL), normalizedURL.host != nil else {
                        return "Please enter a valid URL."
                    }
                    var updated = draft
                    updated.url = normalizedURL
                    vm.updateMonitor(updated)
                    return nil
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            MonitorFormView(
                mode: .add,
                monitor: WebsiteMonitor(
                    url: URL(string: "https://example.com")!,
                    displayName: "",
                    isEnabled: true,
                    method: vm.settings.defaultMethod,
                    body: "",
                    headers: [],
                    allowInsecureSSL: false,
                    thresholdMs: vm.settings.defaultThresholdMs,
                    keyword: ""
                )
            ) { draft, rawURL in
                vm.addMonitor(draft, rawURL: rawURL)
            }
        }
    }

    private var summaryLine: String {
        let active = vm.monitors.filter { $0.isEnabled }.count
        let total = vm.monitors.count
        let upCount = vm.monitors.filter {
            if case .up = vm.statuses[$0.id] ?? .unknown { return true }
            return false
        }.count
        let upPercent = active == 0 ? 0 : Int((Double(upCount) / Double(active)) * 100.0)
        return "\(total) Sites · \(active) Active · \(upPercent)% Up"
    }

    private func statusColor(for status: WebsiteStatus) -> Color {
        switch status {
        case .up: return vm.settings.statusColorUp.color
        case .down: return vm.settings.statusColorFailure.color
        case .checking: return vm.settings.statusColorSlow.color
        case .paused: return vm.settings.statusColorOffline.color
        case .unknown: return vm.settings.statusColorOffline.color.opacity(0.55)
        }
    }

    private func timeLabel(for status: WebsiteStatus) -> String {
        switch status {
        case .up(_, let ms, _): return "\(ms) ms"
        case .down(_, _, let ms, _): return ms.map { "\($0) ms" } ?? "--"
        case .checking: return "Checking"
        case .paused: return "Paused"
        case .unknown: return "--"
        }
    }
}
