import Foundation
import OSLog
import SwiftUI
import AppKit
import Network
import UserNotifications

@MainActor
final class AppViewModel: ObservableObject {
    @Published var monitors: [SiteMonitor]
    @Published var settings: AppSettings
    @Published var statuses: [UUID: SiteStatus] = [:]
    @Published var showSiteManager = false
    @Published var showHistory = false

    private let checker: SiteChecking
    private let monitorStore: MonitorStoreProtocol
    private let historyStore: HistoryStoreProtocol
    private let webhookDispatcher: WebhookDispatching
    private let scheduler = MonitorScheduler()
    private let launchAtLogin: LaunchAtLoginControlling
    private let notifications: NotificationDispatching
    private let logger = Logger(subsystem: "dev.pulse.app", category: "AppViewModel")
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "dev.pulse.app.path-monitor")

    private var inFlight: Set<UUID> = []
    private(set) var previousStatuses: [UUID: SiteStatus] = [:]
    private var consecutiveFailures: [UUID: Int] = [:]
    private var monitorsInAlertingState: Set<UUID> = []
    private var hasStarted = false
    private var isNetworkReachable = true

    init(
        checker: SiteChecking = SiteChecker(),
        monitorStore: MonitorStoreProtocol = MonitorStore(),
        historyStore: HistoryStoreProtocol = HistoryStore(),
        webhookDispatcher: WebhookDispatching = WebhookEngine(),
        launchAtLogin: LaunchAtLoginControlling = LaunchAtLoginService(),
        notifications: NotificationDispatching = NotificationCenterDispatcher(),
        initialNetworkReachable: Bool = true,
        monitorNetworkPath: Bool = true
    ) {
        self.checker = checker
        self.monitorStore = monitorStore
        self.historyStore = historyStore
        self.webhookDispatcher = webhookDispatcher
        self.launchAtLogin = launchAtLogin
        self.notifications = notifications
        self.isNetworkReachable = initialNetworkReachable
        self.monitors = monitorStore.loadMonitors()
        self.settings = monitorStore.loadSettings()
        migrateLegacyWebhookSettingsIfNeeded()

        for monitor in monitors {
            statuses[monitor.id] = monitor.isEnabled ? .unknown : .paused
        }
        updateDockBadge()
        if monitorNetworkPath {
            startPathMonitoring()
        }
    }

    deinit {
        pathMonitor.cancel()
    }

    func start() {
        guard !hasStarted else {
            logger.info("start() ignored; already started")
            return
        }
        hasStarted = true
        logger.info("start() called; interval=\(self.settings.pingIntervalSeconds)")
        Task {
            await scheduler.start(intervalSeconds: settings.pingIntervalSeconds) { [weak self] in
                self?.logger.info("scheduler tick (automatic)")
                await self?.checkAll(autoOnly: true)
            }
        }
        logger.info("trigger initial automatic checkAll")
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

        let monitor = SiteMonitor(url: url, displayName: name)
        monitors.append(monitor)
        statuses[monitor.id] = .unknown
        persistMonitors()
        Task { await check(monitorID: monitor.id, allowPaused: true, trigger: .manual) }
        return nil
    }

    func addMonitor(_ draft: SiteMonitor, rawURL: String) -> String? {
        guard let url = URLInput.normalize(rawURL), url.host != nil else {
            return "Please enter a valid URL."
        }
        var monitor = draft
        monitor.url = url
        monitors.append(monitor)
        statuses[monitor.id] = monitor.isEnabled ? .unknown : .paused
        persistMonitors()
        updateDockBadge()
        Task { await check(monitorID: monitor.id, allowPaused: true, trigger: .manual) }
        return nil
    }

    func updateMonitor(_ updated: SiteMonitor) {
        guard let idx = monitors.firstIndex(where: { $0.id == updated.id }) else { return }
        monitors[idx] = updated
        statuses[updated.id] = updated.isEnabled ? (statuses[updated.id] == .paused ? .unknown : statuses[updated.id] ?? .unknown) : .paused
        persistMonitors()
        updateDockBadge()
    }

    func reorderMonitor(id: UUID, before targetID: UUID) {
        guard let sourceIndex = monitors.firstIndex(where: { $0.id == id }),
              let targetIndex = monitors.firstIndex(where: { $0.id == targetID }),
              sourceIndex != targetIndex else { return }

        let monitor = monitors.remove(at: sourceIndex)
        let insertionIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        monitors.insert(monitor, at: insertionIndex)
        persistMonitors()
    }

    func removeMonitor(id: UUID) {
        monitors.removeAll { $0.id == id }
        statuses.removeValue(forKey: id)
        previousStatuses.removeValue(forKey: id)
        consecutiveFailures.removeValue(forKey: id)
        monitorsInAlertingState.remove(id)
        persistMonitors()
        updateDockBadge()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let idx = monitors.firstIndex(where: { $0.id == id }) else { return }
        monitors[idx].isEnabled = enabled
        statuses[id] = enabled ? .unknown : .paused
        if !enabled {
            consecutiveFailures[id] = 0
            monitorsInAlertingState.remove(id)
        }
        persistMonitors()
        updateDockBadge()
    }

    func checkAll(autoOnly: Bool = false) async {
        if shouldPauseChecks {
            logger.info("checkAll(autoOnly=\(autoOnly, privacy: .public)) skipped; network unavailable")
            return
        }
        let targets = monitors.filter { autoOnly ? $0.isEnabled : true }
        let trigger: HistoryTrigger = autoOnly ? .automatic : .manual
        logger.info("checkAll(autoOnly=\(autoOnly, privacy: .public)) targets=\(targets.count)")

        let delaySeconds = max(0, settings.staggerRequestsSeconds)
        if delaySeconds == 0 {
            await withTaskGroup(of: Void.self) { group in
                for monitor in targets {
                    group.addTask { [weak self] in
                        await self?.check(monitorID: monitor.id, allowPaused: !autoOnly, trigger: trigger)
                    }
                }
            }
            return
        }

        for (index, monitor) in targets.enumerated() {
            await check(monitorID: monitor.id, allowPaused: !autoOnly, trigger: trigger)
            if index < (targets.count - 1) {
                try? await Task.sleep(for: .seconds(delaySeconds))
            }
        }
    }

    func check(monitorID: UUID, allowPaused: Bool = false, trigger: HistoryTrigger = .manual) async {
        if shouldPauseChecks {
            logger.info("check skipped monitor=\(monitorID.uuidString, privacy: .public) trigger=\(trigger.rawValue, privacy: .public) reason=networkUnavailable")
            return
        }
        guard !inFlight.contains(monitorID) else {
            logger.info("check skipped monitor=\(monitorID.uuidString, privacy: .public) reason=inFlight")
            return
        }
        guard let monitor = monitors.first(where: { $0.id == monitorID }) else {
            logger.error("check skipped monitor=\(monitorID.uuidString, privacy: .public) reason=missingMonitor")
            return
        }
        if !monitor.isEnabled && !allowPaused {
            logger.info("check skipped monitor=\(monitor.id.uuidString, privacy: .public) reason=pausedAuto")
            return
        }

        inFlight.insert(monitorID)
        logger.info("check start monitor=\(monitor.id.uuidString, privacy: .public) trigger=\(trigger.rawValue, privacy: .public)")
        let previousBeforeChecking = statuses[monitorID] ?? .unknown
        statuses[monitorID] = .checking

        let result = await checker.check(monitor)
        let finalStatus: SiteStatus
        if monitor.isEnabled {
            finalStatus = result.status
        } else {
            // Manual checks on paused sites should still persist real result in history,
            // but paused sites remain paused in current UI status.
            finalStatus = .paused
        }

        previousStatuses[monitorID] = previousBeforeChecking
        statuses[monitorID] = finalStatus
        updateDockBadge()
        logger.info("check done monitor=\(monitor.id.uuidString, privacy: .public)")

        handleAlertTransitions(
            monitor: monitor,
            current: result.status,
            trigger: trigger
        )

        if case .up(let code, let duration, let checkedAt) = result.status {
            historyStore.append(
                HistoryEvent(timestamp: checkedAt, monitorID: monitor.id, monitorName: monitor.nameOrHost, url: monitor.url.absoluteString, method: result.methodUsed.rawValue, status: "OK", statusCode: code, durationMs: duration, reason: nil, trigger: trigger),
                retentionPolicy: settings.historyRetentionPolicy,
                maxEvents: settings.historyRetentionMaxEvents
            )
        } else if case .down(let reason, let code, let duration, let checkedAt) = result.status {
            historyStore.append(
                HistoryEvent(timestamp: checkedAt, monitorID: monitor.id, monitorName: monitor.nameOrHost, url: monitor.url.absoluteString, method: result.methodUsed.rawValue, status: "Down", statusCode: code, durationMs: duration, reason: reason, trigger: trigger),
                retentionPolicy: settings.historyRetentionPolicy,
                maxEvents: settings.historyRetentionMaxEvents
            )
        }

        inFlight.remove(monitorID)
    }

    func saveSettings() {
        migrateLegacyWebhookSettingsIfNeeded()
        monitorStore.saveSettings(settings)
        launchAtLogin.setEnabled(settings.launchAtLogin)
        updateDockBadge()
        Task {
            await scheduler.start(intervalSeconds: settings.pingIntervalSeconds) { [weak self] in
                await self?.checkAll(autoOnly: true)
            }
        }
    }

    private func persistMonitors() {
        monitorStore.saveMonitors(monitors)
    }

    private func maybeSendWebhookTransition(previous: SiteStatus, current: SiteStatus, monitor: SiteMonitor, trigger: HistoryTrigger) {
        guard monitor.isEnabled else { return }
        guard !settings.webhookConfigs.isEmpty else { return }

        let previousStable = stableStatus(previous)
        let currentStable = stableStatus(current)
        let event: WebhookTransitionEvent?
        let eventStatus: String?

        switch (previousStable, currentStable) {
        case (.up, .down):
            event = buildTransitionEvent(
                message: "\(monitor.nameOrHost) is down",
                status: "down",
                current: current,
                monitor: monitor,
                trigger: trigger
            )
            eventStatus = "down"
        case (.down, .up):
            event = buildTransitionEvent(
                message: "\(monitor.nameOrHost) recovered",
                status: "up",
                current: current,
                monitor: monitor,
                trigger: trigger
            )
            eventStatus = "up"
        default:
            event = nil
            eventStatus = nil
        }

        guard let event, let eventStatus else { return }

        for config in matchingWebhookConfigs(for: monitor.id, status: eventStatus) {
            webhookDispatcher.sendTransition(event: event, config: config)
        }
    }

    private func buildTransitionEvent(message: String, status: String, current: SiteStatus, monitor: SiteMonitor, trigger: HistoryTrigger) -> WebhookTransitionEvent {
        let code: Int?
        let ms: Int?
        switch current {
        case .up(let statusCode, let responseMs, _):
            code = statusCode
            ms = responseMs
        case .down(_, let statusCode, let responseMs, _):
            code = statusCode
            ms = responseMs
        case .unknown, .checking, .paused:
            code = nil
            ms = nil
        }

        return WebhookTransitionEvent(
            message: message,
            monitorName: monitor.nameOrHost,
            monitorURL: monitor.url.absoluteString,
            status: status,
            trigger: trigger.rawValue,
            statusCode: code,
            responseMs: ms,
            timestamp: Date()
        )
    }

    private enum StableStatus {
        case up
        case down
        case other
    }

    private func stableStatus(_ status: SiteStatus) -> StableStatus {
        switch status {
        case .up: return .up
        case .down: return .down
        case .unknown, .checking, .paused: return .other
        }
    }

    private var shouldPauseChecks: Bool {
        settings.pausePingWhen == .offline && !isNetworkReachable
    }

    private func startPathMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isNetworkReachable = (path.status == .satisfied)
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    private func handleAlertTransitions(monitor: SiteMonitor, current: SiteStatus, trigger: HistoryTrigger) {
        guard monitor.isEnabled else { return }

        let previousFailures = consecutiveFailures[monitor.id, default: 0]
        let failureThreshold = max(1, settings.failuresToAlert)
        let wasAlerting = monitorsInAlertingState.contains(monitor.id)

        let currentFailures: Int
        switch current {
        case .down:
            currentFailures = previousFailures + 1
        case .up, .unknown, .checking, .paused:
            currentFailures = 0
        }
        consecutiveFailures[monitor.id] = currentFailures
        let isAlerting = currentFailures >= failureThreshold

        if !wasAlerting && isAlerting {
            maybeSendWebhookTransition(
                previous: .up(statusCode: 200, responseTimeMs: 0, checkedAt: Date()),
                current: current,
                monitor: monitor,
                trigger: trigger
            )
            if case .down(let reason, let code, _, _) = current {
                let at = notificationTimestampText()
                notifications.send(
                    title: "\(monitor.nameOrHost) is down",
                    body: (code.map { "\(reason) (\($0))" } ?? reason) + "\nAt: \(at)"
                )
            }
            monitorsInAlertingState.insert(monitor.id)
            return
        }

        if wasAlerting, case .up = current {
            maybeSendWebhookTransition(
                previous: .down(reason: "Failure threshold reached", statusCode: nil, responseTimeMs: nil, checkedAt: Date()),
                current: current,
                monitor: monitor,
                trigger: trigger
            )
            let at = notificationTimestampText()
            notifications.send(
                title: "\(monitor.nameOrHost) recovered",
                body: "Site is reachable again.\nAt: \(at)"
            )
            monitorsInAlertingState.remove(monitor.id)
        }
    }

    private func notificationTimestampText() -> String {
        Date.now.formatted(date: .abbreviated, time: .standard)
    }

    private func updateDockBadge() {
        guard NSApp != nil else {
            return
        }
        guard settings.showAlertBadgeOnDockIcon else {
            NSApp.dockTile.badgeLabel = nil
            return
        }

        let alertCount = monitors.reduce(into: 0) { count, monitor in
            guard monitor.isEnabled else { return }
            let status = statuses[monitor.id] ?? .unknown
            if isAlertingStatus(status) {
                count += 1
            }
        }

        NSApp.dockTile.badgeLabel = alertCount > 0 ? "\(alertCount)" : nil
    }

    private func isAlertingStatus(_ status: SiteStatus) -> Bool {
        switch status {
        case .down:
            return true
        case .up(_, let responseMs, _):
            return responseMs > settings.defaultThresholdMs
        case .unknown, .checking, .paused:
            return false
        }
    }

    private func matchingWebhookConfigs(for monitorID: UUID, status: String) -> [WebhookConfig] {
        settings.webhookConfigs.filter { config in
            guard config.isEnabled else { return false }
            guard !config.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

            let appliesToStatus: Bool = {
                switch status {
                case "down":
                    return true
                case "up":
                    return config.sendOn == .alertingAndRecovery
                default:
                    return false
                }
            }()
            guard appliesToStatus else { return false }

            switch config.scope {
            case .allSites:
                return true
            case .selectedSites:
                return config.monitorIDs.contains(monitorID)
            }
        }
    }

    private func migrateLegacyWebhookSettingsIfNeeded() {
        if !settings.webhookConfigs.isEmpty { return }
        let hasLegacyData =
            !settings.webhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            settings.webhookEnabled
        guard hasLegacyData else { return }

        let config = WebhookConfig(
            name: "Primary Webhook",
            isEnabled: settings.webhookEnabled,
            url: settings.webhookURL,
            method: settings.webhookMethod,
            sendOn: settings.webhookSendOn,
            payloadTemplate: settings.webhookPayloadTemplate,
            maxRetries: settings.webhookMaxRetries,
            initialBackoffSeconds: settings.webhookInitialBackoffSeconds,
            scope: .allSites,
            monitorIDs: []
        )
        settings.webhookConfigs = [config]
    }
}

protocol NotificationDispatching {
    func send(title: String, body: String)
}

final class NotificationCenterDispatcher: NotificationDispatching {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func send(title: String, body: String) {
        center.getNotificationSettings { [weak center] settings in
            guard let center else { return }

            let schedule: () -> Void = {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                center.add(request)
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                schedule()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        schedule()
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }
}
