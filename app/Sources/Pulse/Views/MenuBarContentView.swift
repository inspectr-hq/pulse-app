import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 8) {
            ForEach(vm.monitors.prefix(vm.settings.menuMaxItems)) { monitor in
                let status = vm.statuses[monitor.id] ?? .unknown
                HStack {
                    Circle().fill(color(for: status)).frame(width: 10, height: 10)
                    if vm.settings.showMethodInMenu { Text(monitor.method.rawValue).font(.caption).foregroundStyle(.secondary) }
                    Text(monitor.nameOrHost)
                    Spacer()
                    if vm.settings.showResponseTimeInMenu, case .up(_, let ms, _) = status { Text("\(ms) ms").foregroundStyle(.secondary) }
                    if vm.settings.showStatusCodeInMenu {
                        switch status {
                        case .up(let code, _, _): Text("\(code)").foregroundStyle(.secondary)
                        case .down(_, let code, _, _): Text(code.map(String.init) ?? "-").foregroundStyle(.secondary)
                        default: EmptyView()
                        }
                    }
                }
            }
            Divider()
            Button("Ping now…") { Task { await vm.checkAll(autoOnly: false) } }
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Site Manager") { openWindow(id: "site-manager") }
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("History Logs") { openWindow(id: "history") }
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            Button("Quit Pulse") { NSApp.terminate(nil) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(width: 280, alignment: .leading)
        .onAppear { vm.start() }
    }

    private func color(for status: WebsiteStatus) -> Color {
        switch status {
        case .up: return .green
        case .down: return .red
        case .checking: return .yellow
        case .paused: return .gray
        case .unknown: return .gray.opacity(0.7)
        }
    }
}
