import SwiftUI
import OSLog
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject var vm: AppViewModel
    private let logger = Logger(subsystem: "dev.pulse.app", category: "MenuBar")

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Self.visibleMonitors(
                monitors: vm.monitors,
                hidePausedSitesInMenuBar: vm.settings.hidePausedSitesInMenuBar
            ).prefix(vm.settings.menuMaxItems)) { monitor in
                let status = vm.statuses[monitor.id] ?? .unknown
                HStack(spacing: 8) {
                    Button {
                        logger.info("Menu click: Monitor row \(monitor.id.uuidString, privacy: .public)")
                        Task { await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .manual) }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Circle().fill(color(for: status)).frame(width: 11, height: 11)
                                if vm.settings.showMethodInMenu {
                                    Text(monitor.method.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .leading)
                                }
                                Text(monitor.nameOrHost)
                                    .lineLimit(1)
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                if vm.settings.showResponseTimeInMenu {
                                    Text(responseTimeLabel(for: status))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 70, alignment: .leading)
                                }
                                if vm.settings.showLastCheckedInMenu, let checked = checkedAt(for: status) {
                                    Text(timeString(checked))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 72, alignment: .leading)
                                } else if vm.settings.showLastCheckedInMenu {
                                    Text("--:--:--")
                                        .font(.callout)
                                        .foregroundStyle(.secondary.opacity(0.5))
                                        .frame(width: 72, alignment: .leading)
                                }
                                Spacer()
                                if vm.settings.showStatusCodeInMenu, let code = statusCode(for: status) {
                                    Text("\(code)")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 34, alignment: .trailing)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        if isHovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
                    if let monitorAction = Self.accessoryAction(for: monitor) {
                        Button {
                            performAccessoryAction(for: monitor, action: monitorAction)
                        } label: {
                            Image(systemName: monitorAction.iconName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .help(monitorAction.helpText)
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            Divider()
            menuAction("Check Now…") {
                logger.info("Menu click: Check now")
                Task { await vm.checkAll(autoOnly: false) }
            }
            Divider()
            menuAction("Site Manager") {
                logger.info("Menu click: Site Manager")
                WindowManager.shared.showSiteManager(appVM: vm)
            }
            Divider()
            menuAction("Dashboard") {
                logger.info("Menu click: Dashboard")
                WindowManager.shared.showHistoryReports(appVM: vm)
            }
            menuAction("History Logs") {
                logger.info("Menu click: History Logs")
                WindowManager.shared.showHistory(appVM: vm)
            }
            Divider()
            menuAction("Settings…") {
                logger.info("Menu click: Settings")
                WindowManager.shared.showSettings(appVM: vm)
            }
            Divider()
            menuAction("Quit Pulse") {
                logger.info("Menu click: Quit")
                NSApp.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 280, alignment: .leading)
        .onAppear {
            logger.info("MenuBarContentView appeared")
            vm.start()
        }
    }

    static func visibleMonitors(monitors: [SiteMonitor], hidePausedSitesInMenuBar: Bool) -> [SiteMonitor] {
        if hidePausedSitesInMenuBar {
            return monitors.filter { $0.isEnabled }
        }
        return monitors
    }

    @ViewBuilder
    private func menuAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func color(for status: SiteStatus) -> Color {
        switch status {
        case .up: return vm.settings.statusColorUp.color
        case .down: return vm.settings.statusColorFailure.color
        case .checking: return vm.settings.statusColorSlow.color
        case .paused: return vm.settings.statusColorOffline.color
        case .unknown: return vm.settings.statusColorOffline.color.opacity(0.7)
        }
    }

    private func responseTimeLabel(for status: SiteStatus) -> String {
        switch status {
        case .up(_, let ms, _):
            return "\(ms) ms"
        case .down(_, _, let ms, _):
            return ms.map { "\($0) ms" } ?? "--"
        case .checking:
            return "Checking..."
        case .paused:
            return "Paused"
        case .unknown:
            return "Not checked"
        }
    }

    private func statusCode(for status: SiteStatus) -> Int? {
        switch status {
        case .up(let code, _, _):
            return code
        case .down(_, let code, _, _):
            return code
        case .checking, .paused, .unknown:
            return nil
        }
    }

    private func checkedAt(for status: SiteStatus) -> Date? {
        switch status {
        case .up(_, _, let checked):
            return checked
        case .down(_, _, _, let checked):
            return checked
        case .checking, .paused, .unknown:
            return nil
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    enum MenuBarAccessoryAction {
        case openURL
        case copyCurl

        var iconName: String {
            switch self {
            case .openURL: return "safari"
            case .copyCurl: return "terminal"
            }
        }

        var helpText: String {
            switch self {
            case .openURL: return "Open in browser"
            case .copyCurl: return "Copy curl command"
            }
        }
    }

    static func accessoryAction(for monitor: SiteMonitor) -> MenuBarAccessoryAction? {
        switch monitor.method {
        case .get:
            return .openURL
        case .post, .head:
            return .copyCurl
        }
    }

    private func performAccessoryAction(for monitor: SiteMonitor, action: MenuBarAccessoryAction) {
        switch action {
        case .openURL:
            NSWorkspace.shared.open(monitor.url)
        case .copyCurl:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Self.curlCommand(for: monitor), forType: .string)
        }
    }

    static func curlCommand(for monitor: SiteMonitor) -> String {
        var components: [String] = ["curl"]
        if monitor.method == .head {
            components.append("-I")
        } else {
            components.append("-X")
            components.append(monitor.method.rawValue)
        }

        for header in monitor.headers where !header.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let escapedValue = header.value.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H")
            components.append("\"\(header.name): \(escapedValue)\"")
        }

        if !monitor.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let escapedBody = monitor.body
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            components.append("--data-raw")
            components.append("\"\(escapedBody)\"")
        }

        components.append("\"\(monitor.url.absoluteString)\"")
        return components.joined(separator: " ")
    }
}
