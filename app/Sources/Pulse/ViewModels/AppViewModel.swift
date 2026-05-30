import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var monitors: [WebsiteMonitor]
    @Published var settings: AppSettings
    @Published var statuses: [UUID: WebsiteStatus] = [:]
    @Published var showSiteManager = false
    @Published var showHistory = false

    private let checker: WebsiteChecking
    private let monitorStore: MonitorStoreProtocol
    private let historyStore: HistoryStoreProtocol
    private let scheduler = MonitorScheduler()
    private let launchAtLogin: LaunchAtLoginControlling

    private var inFlight: Set<UUID> = []
    private(set) var previousStatuses: [UUID: WebsiteStatus] = [:]

    init(
        checker: WebsiteChecking = WebsiteChecker(),
        monitorStore: MonitorStoreProtocol = MonitorStore(),
        historyStore: HistoryStoreProtocol = HistoryStore(),
        launchAtLogin: LaunchAtLoginControlling = LaunchAtLoginService()
    ) {
        self.checker = checker
        self.monitorStore = monitorStore
        self.historyStore = historyStore
        self.launchAtLogin = launchAtLogin
        self.monitors = monitorStore.loadMonitors()
        self.settings = monitorStore.loadSettings()

        for monitor in monitors {
            statuses[monitor.id] = monitor.isEnabled ? .unknown : .paused
        }
    }

    func start() {
        Task {
            await scheduler.start(intervalSeconds: settings.pingIntervalSeconds) { [weak self] in
                await self?.checkAll(autoOnly: true)
            }
        }
        Task { await checkAll(autoOnly: true) }
    }

    func stop() {
        Task { await scheduler.stop() }
    }

    var overallStatus: OverallStatus {
        let enabled = monitors.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return .neutral }

        var anyUp = false
        var anyDown = false
        var anyChecking = false
        var anyCompleted = false

        for monitor in enabled {
            switch statuses[monitor.id] ?? .unknown {
            case .up:
                anyUp = true
                anyCompleted = true
            case .down:
                anyDown = true
                anyCompleted = true
            case .checking:
                anyChecking = true
            case .unknown:
                break
            case .paused:
                break
            }
        }

        if anyDown { return .down }
        if anyChecking { return .checking }
        if anyUp { return .up }
        if !anyCompleted { return .unknown }
        return .neutral
    }

    func addMonitor(rawURL: String, name: String) -> String? {
        guard let url = URLInput.normalize(rawURL), url.host != nil else {
            return "Please enter a valid URL."
        }

        let monitor = WebsiteMonitor(url: url, displayName: name)
        monitors.append(monitor)
        statuses[monitor.id] = .unknown
        persistMonitors()
        Task { await check(monitorID: monitor.id, allowPaused: true, trigger: .manual) }
        return nil
    }

    func updateMonitor(_ updated: WebsiteMonitor) {
        guard let idx = monitors.firstIndex(where: { $0.id == updated.id }) else { return }
        monitors[idx] = updated
        statuses[updated.id] = updated.isEnabled ? (statuses[updated.id] == .paused ? .unknown : statuses[updated.id] ?? .unknown) : .paused
        persistMonitors()
    }

    func removeMonitor(id: UUID) {
        monitors.removeAll { $0.id == id }
        statuses.removeValue(forKey: id)
        previousStatuses.removeValue(forKey: id)
        persistMonitors()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let idx = monitors.firstIndex(where: { $0.id == id }) else { return }
        monitors[idx].isEnabled = enabled
        statuses[id] = enabled ? .unknown : .paused
        persistMonitors()
    }

    func checkAll(autoOnly: Bool = false) async {
        let targets = monitors.filter { autoOnly ? $0.isEnabled : true }
        let trigger: HistoryTrigger = autoOnly ? .automatic : .manual
        await withTaskGroup(of: Void.self) { group in
            for monitor in targets {
                group.addTask { [weak self] in
                    await self?.check(monitorID: monitor.id, allowPaused: !autoOnly, trigger: trigger)
                }
            }
        }
    }

    func check(monitorID: UUID, allowPaused: Bool = false, trigger: HistoryTrigger = .manual) async {
        guard !inFlight.contains(monitorID) else { return }
        guard let monitor = monitors.first(where: { $0.id == monitorID }) else { return }
        if !monitor.isEnabled && !allowPaused { return }

        inFlight.insert(monitorID)
        let previousBeforeChecking = statuses[monitorID] ?? .unknown
        statuses[monitorID] = .checking

        let result = await checker.check(monitor)
        let finalStatus: WebsiteStatus
        if monitor.isEnabled {
            finalStatus = result.status
        } else {
            // Manual checks on paused sites should still persist real result in history,
            // but paused sites remain paused in current UI status.
            finalStatus = .paused
        }

        previousStatuses[monitorID] = previousBeforeChecking
        statuses[monitorID] = finalStatus

        if case .up(let code, let duration, let checkedAt) = result.status {
            historyStore.append(
                HistoryEvent(timestamp: checkedAt, monitorID: monitor.id, monitorName: monitor.nameOrHost, url: monitor.url.absoluteString, method: result.methodUsed.rawValue, status: "OK", statusCode: code, durationMs: duration, reason: nil, trigger: trigger),
                maxEvents: settings.historyRetentionMaxEvents
            )
        } else if case .down(let reason, let code, let duration, let checkedAt) = result.status {
            historyStore.append(
                HistoryEvent(timestamp: checkedAt, monitorID: monitor.id, monitorName: monitor.nameOrHost, url: monitor.url.absoluteString, method: result.methodUsed.rawValue, status: "Down", statusCode: code, durationMs: duration, reason: reason, trigger: trigger),
                maxEvents: settings.historyRetentionMaxEvents
            )
        }

        inFlight.remove(monitorID)
    }

    func saveSettings() {
        monitorStore.saveSettings(settings)
        launchAtLogin.setEnabled(settings.launchAtLogin)
        Task {
            await scheduler.start(intervalSeconds: settings.pingIntervalSeconds) { [weak self] in
                await self?.checkAll(autoOnly: true)
            }
        }
    }

    private func persistMonitors() {
        monitorStore.saveMonitors(monitors)
    }
}
