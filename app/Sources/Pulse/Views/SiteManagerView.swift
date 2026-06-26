import SwiftUI
import UniformTypeIdentifiers

struct SiteManagerView: View {
    struct ConfigurationExport: Codable, Equatable {
        var appName: String
        var appVersion: String
        var exportedAt: Date
        var monitors: [SiteMonitor]
        var settings: AppSettings
    }

    @EnvironmentObject var vm: AppViewModel
    @State private var showAdd = false
    @State private var editing: SiteMonitor?
    @State private var pendingRemoval: SiteMonitor?
    @State private var draggingMonitorID: UUID?

    private let dragHandleWidth: CGFloat = 20
    private let activeWidth: CGFloat = 44
    private let statusWidth: CGFloat = 44
    private let timeWidth: CGFloat = 72
    private let nameWidth: CGFloat = 180
    private let urlWidth: CGFloat = 240
    private let methodWidth: CGFloat = 56
    private let actionsWidth: CGFloat = 280

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
                Button("Export JSON") {
                    exportConfiguration()
                }
                Button {
                    showAdd = true
                } label: {
                    Label("Add site", systemImage: "plus")
                }
                Button(action: { Task { await vm.checkAll(autoOnly: false) } }) { Image(systemName: "arrow.clockwise") }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()

            VStack(spacing: 0) {
                headerRow
                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(vm.monitors.enumerated()), id: \.element.id) { index, monitor in
                            siteRow(monitor: monitor, rowIndex: index)
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
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
                monitor: SiteMonitor(
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
        .confirmationDialog(
            Self.removeConfirmationTitle,
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingRemoval = nil
                    }
                }
            ),
            presenting: pendingRemoval
        ) { monitor in
            Button("Remove", role: .destructive) {
                vm.removeMonitor(id: monitor.id)
                pendingRemoval = nil
            }
        } message: { monitor in
            Text(Self.removeConfirmationMessage(for: monitor))
        }
    }

    static let removeConfirmationTitle = "Remove Site?"

    static func configurationExportData(
        monitors: [SiteMonitor],
        settings: AppSettings,
        exportedAt: Date = Date()
    ) throws -> Data {
        let export = ConfigurationExport(
            appName: SettingsView.appDisplayName,
            appVersion: AppUpdateChecker.currentAppVersion(),
            exportedAt: exportedAt,
            monitors: monitors,
            settings: settings
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    static func removeConfirmationMessage(for monitor: SiteMonitor) -> String {
        "Are you sure you want to remove \"\(monitor.nameOrHost)\"? This cannot be undone."
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Text("")
                .frame(width: dragHandleWidth, alignment: .center)
            Text("Active")
                .frame(width: activeWidth, alignment: .center)
            Text("Status")
                .frame(width: statusWidth, alignment: .center)
            Text("Time")
                .frame(width: timeWidth, alignment: .leading)
            Text("Name")
                .frame(width: nameWidth, alignment: .leading)
            Text("URL")
                .frame(width: urlWidth, alignment: .leading)
            Text("Method")
                .frame(width: methodWidth, alignment: .leading)
            Text("Actions")
                .frame(width: actionsWidth, alignment: .leading)
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func siteRow(monitor: SiteMonitor, rowIndex: Int) -> some View {
        let status = vm.statuses[monitor.id] ?? .unknown
        let isDragging = draggingMonitorID == monitor.id

        return HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.55))
                .frame(width: dragHandleWidth, alignment: .center)
                .accessibilityHidden(true)
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.openHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }

            Toggle("", isOn: Binding(get: { monitor.isEnabled }, set: { vm.setEnabled($0, for: monitor.id) }))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: activeWidth, alignment: .center)

            Circle()
                .fill(statusColor(for: status))
                .frame(width: 11, height: 11)
                .frame(width: statusWidth, alignment: .center)

            Text(timeLabel(for: status))
                .foregroundStyle(.secondary)
                .frame(width: timeWidth, alignment: .leading)

            Text(monitor.nameOrHost)
                .lineLimit(1)
                .frame(width: nameWidth, alignment: .leading)

            Text(monitor.url.absoluteString)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: urlWidth, alignment: .leading)

            Text(monitor.method.rawValue)
                .foregroundStyle(.secondary)
                .frame(width: methodWidth, alignment: .leading)

            HStack(spacing: 10) {
                Button("Edit") { editing = monitor }
                Button("Duplicate") { vm.duplicateMonitor(id: monitor.id) }
                Button("Check") {
                    Task { await vm.checkMonitor(id: monitor.id) }
                }
                Button("Remove") { pendingRemoval = monitor }
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: actionsWidth, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isDragging ? Color.accentColor.opacity(0.08) : (rowIndex.isMultiple(of: 2) ? Color.secondary.opacity(0.03) : Color.clear))
        .contentShape(Rectangle())
        .onDrag {
            draggingMonitorID = monitor.id
            return NSItemProvider(object: monitor.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: SiteManagerRowDropDelegate(
            targetID: monitor.id,
            draggingMonitorID: $draggingMonitorID
        ) { draggedID, targetID in
            vm.reorderMonitor(id: draggedID, before: targetID)
        })
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

    private func statusColor(for status: SiteStatus) -> Color {
        switch status {
        case .up: return vm.settings.statusColorUp.color
        case .down: return vm.settings.statusColorFailure.color
        case .checking: return vm.settings.statusColorSlow.color
        case .paused: return vm.settings.statusColorOffline.color
        case .unknown: return vm.settings.statusColorOffline.color.opacity(0.55)
        }
    }

    private func timeLabel(for status: SiteStatus) -> String {
        switch status {
        case .up(_, let ms, _): return "\(ms) ms"
        case .down(_, _, let ms, _): return ms.map { "\($0) ms" } ?? "--"
        case .checking: return "Checking"
        case .paused: return "Paused"
        case .unknown: return "--"
        }
    }

    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultJSONFileName()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Self.configurationExportData(
                monitors: vm.monitors,
                settings: vm.settings
            )
            try data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }

    private func defaultJSONFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "pulse-config-\(formatter.string(from: Date())).json"
    }
}

struct SiteManagerRowDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingMonitorID: UUID?
    let onReorder: (UUID, UUID) -> Void

    static func moveDropProposal() -> DropProposal {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggingMonitorID, draggingMonitorID != targetID else { return }
        onReorder(draggingMonitorID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        Self.moveDropProposal()
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingMonitorID = nil
        return true
    }
}
