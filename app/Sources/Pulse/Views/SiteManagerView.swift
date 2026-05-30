import SwiftUI

struct SiteManagerView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showAdd = false
    @State private var editing: WebsiteMonitor?

    var body: some View {
        VStack {
            HStack {
                Text("Site Manager").font(.headline)
                Spacer()
                Button(action: { showAdd = true }) { Image(systemName: "plus") }
                Button(action: { Task { await vm.checkAll(autoOnly: false) } }) { Image(systemName: "arrow.clockwise") }
            }
            .padding()

            Table(vm.monitors) {
                TableColumn("Active") { monitor in
                    Toggle("", isOn: Binding(get: { monitor.isEnabled }, set: { vm.setEnabled($0, for: monitor.id) }))
                }
                TableColumn("Name") { monitor in Text(monitor.nameOrHost) }
                TableColumn("URL") { monitor in Text(monitor.url.absoluteString) }
                TableColumn("Method") { monitor in Text(monitor.method.rawValue) }
                TableColumn("Status") { monitor in Text(label(for: vm.statuses[monitor.id] ?? .unknown)) }
                TableColumn("Actions") { monitor in
                    HStack {
                        Button("Edit") { editing = monitor }
                        Button("Remove") { vm.removeMonitor(id: monitor.id) }
                    }
                }
            }
            .sheet(item: $editing) { item in
                EditMonitorView(monitor: item) { vm.updateMonitor($0) }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddMonitorView { url, name in vm.addMonitor(rawURL: url, name: name) }
        }
    }

    private func label(for status: WebsiteStatus) -> String {
        switch status {
        case .unknown: return "Unknown"
        case .checking: return "Checking..."
        case .up(_, let ms, _): return "Up · \(ms) ms"
        case .down(let reason, _, _, _): return "Down · \(reason)"
        case .paused: return "Paused"
        }
    }
}
