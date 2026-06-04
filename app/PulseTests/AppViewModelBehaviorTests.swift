import XCTest
@testable import Pulse

@MainActor
final class AppViewModelBehaviorTests: XCTestCase {
    func testAddMonitorPersistsAndInitializesUnknownStatus() {
        let store = SpyMonitorStore(monitors: [])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )

        let error = vm.addMonitor(rawURL: "inspectr.dev", name: "Inspectr")

        XCTAssertNil(error)
        XCTAssertEqual(vm.monitors.count, 1)
        XCTAssertEqual(vm.monitors[0].displayName, "Inspectr")
        XCTAssertEqual(vm.monitors[0].url.absoluteString, "https://inspectr.dev")
        XCTAssertEqual(vm.statuses[vm.monitors[0].id], .unknown)
        XCTAssertEqual(store.savedMonitorsCalls, 1)
    }

    func testAddMonitorRejectsInvalidURL() {
        let store = SpyMonitorStore(monitors: [])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )

        let error = vm.addMonitor(rawURL: "", name: "Bad")

        XCTAssertNotNil(error)
        XCTAssertEqual(vm.monitors.count, 0)
        XCTAssertEqual(store.savedMonitorsCalls, 0)
    }

    func testUpdateMonitorPersistsChanges() {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A")
        let store = SpyMonitorStore(monitors: [monitor])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )

        var updated = monitor
        updated.displayName = "A2"
        updated.thresholdMs = 3000
        vm.updateMonitor(updated)

        XCTAssertEqual(vm.monitors[0].displayName, "A2")
        XCTAssertEqual(vm.monitors[0].thresholdMs, 3000)
        XCTAssertEqual(store.savedMonitorsCalls, 1)
    }

    func testRemoveMonitorDeletesStateAndPersists() {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A")
        let store = SpyMonitorStore(monitors: [monitor])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )

        vm.removeMonitor(id: monitor.id)

        XCTAssertTrue(vm.monitors.isEmpty)
        XCTAssertNil(vm.statuses[monitor.id])
        XCTAssertEqual(store.savedMonitorsCalls, 1)
    }

    func testReorderMonitorMovesItemAndPersistsOrder() {
        let first = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A")
        let second = SiteMonitor(url: URL(string: "https://b.com")!, displayName: "B")
        let third = SiteMonitor(url: URL(string: "https://c.com")!, displayName: "C")
        let store = SpyMonitorStore(monitors: [first, second, third])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )

        vm.reorderMonitor(id: third.id, before: first.id)

        XCTAssertEqual(vm.monitors.map(\.displayName), ["C", "A", "B"])
        XCTAssertEqual(store.savedMonitorsCalls, 1)
        XCTAssertEqual(store.monitors.map(\.displayName), ["C", "A", "B"])
    }

    func testSaveSettingsPersistsAndCallsLaunchAtLogin() {
        let launchSpy = SpyLaunchAtLogin()
        let store = SpyMonitorStore(monitors: [])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: launchSpy,
            notifications: SpyNotifications()
        )

        vm.settings.launchAtLogin = true
        vm.settings.pingIntervalSeconds = 120
        vm.saveSettings()

        XCTAssertEqual(store.savedSettingsCalls, 1)
        XCTAssertEqual(store.lastSavedSettings?.pingIntervalSeconds, 120)
        XCTAssertEqual(launchSpy.lastValue, true)
    }

    func testCheckWritesHistoryEventForUpResult() async throws {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let historySpy = SpyHistoryStore()
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 88, checkedAt: Date(timeIntervalSince1970: 1_700_000_010))),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .manual)

        XCTAssertEqual(historySpy.events.count, 1)
        let event = try XCTUnwrap(historySpy.events.first)
        XCTAssertEqual(event.method, "GET")
        XCTAssertEqual(event.status, "OK")
        XCTAssertEqual(event.statusCode, 200)
        XCTAssertEqual(event.durationMs, 88)
        XCTAssertEqual(event.trigger, .manual)
    }

    func testCheckWritesHistoryEventForDownResult() async throws {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .head)
        let historySpy = SpyHistoryStore()
        let vm = AppViewModel(
            checker: StaticChecker(.down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 55, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(historySpy.events.count, 1)
        let event = try XCTUnwrap(historySpy.events.first)
        XCTAssertEqual(event.status, "Down")
        XCTAssertEqual(event.statusCode, 500)
        XCTAssertEqual(event.trigger, .automatic)
    }

    func testPausedSiteManualCheckStaysPausedButStillLogsRealResult() async {
        let paused = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: false, method: .get)
        let historySpy = SpyHistoryStore()
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 44, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [paused]),
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )

        await vm.check(monitorID: paused.id, allowPaused: true, trigger: .manual)

        XCTAssertEqual(vm.statuses[paused.id], .paused)
        XCTAssertEqual(historySpy.events.count, 1)
        XCTAssertEqual(historySpy.events.first?.trigger, .manual)
        XCTAssertEqual(historySpy.events.first?.status, "OK")
    }

    func testManualCheckSkipsWhenOfflineAndPauseWhenOfflineIsEnabled() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let historySpy = SpyHistoryStore()
        let checker = CountingChecker(.up(statusCode: 200, responseTimeMs: 44, checkedAt: Date()))
        var settings = AppSettings()
        settings.pausePingWhen = .offline
        let store = SpyMonitorStore(monitors: [monitor], settings: settings)
        let vm = AppViewModel(
            checker: checker,
            monitorStore: store,
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications(),
            initialNetworkReachable: false,
            monitorNetworkPath: false
        )

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .manual)

        XCTAssertEqual(checker.calls, 0)
        XCTAssertEqual(historySpy.events.count, 0)
        XCTAssertEqual(vm.statuses[monitor.id], .unknown)
    }

    func testAutomaticCheckAllSkipsWhenOfflineAndPauseWhenOfflineIsEnabled() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let historySpy = SpyHistoryStore()
        let checker = CountingChecker(.up(statusCode: 200, responseTimeMs: 44, checkedAt: Date()))
        var settings = AppSettings()
        settings.pausePingWhen = .offline
        let store = SpyMonitorStore(monitors: [monitor], settings: settings)
        let vm = AppViewModel(
            checker: checker,
            monitorStore: store,
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications(),
            initialNetworkReachable: false,
            monitorNetworkPath: false
        )

        await vm.checkAll(autoOnly: true)

        XCTAssertEqual(checker.calls, 0)
        XCTAssertEqual(historySpy.events.count, 0)
        XCTAssertEqual(vm.statuses[monitor.id], .unknown)
    }

    func testAutomaticSingleCheckSkipsWhenOfflineAndPauseWhenOfflineIsEnabled() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let historySpy = SpyHistoryStore()
        let checker = CountingChecker(.up(statusCode: 200, responseTimeMs: 44, checkedAt: Date()))
        var settings = AppSettings()
        settings.pausePingWhen = .offline
        let store = SpyMonitorStore(monitors: [monitor], settings: settings)
        let vm = AppViewModel(
            checker: checker,
            monitorStore: store,
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications(),
            initialNetworkReachable: false,
            monitorNetworkPath: false
        )
        let previousCheckedAt = Date(timeIntervalSince1970: 1_700_000_100)
        vm.statuses[monitor.id] = .up(statusCode: 200, responseTimeMs: 10, checkedAt: previousCheckedAt)

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(checker.calls, 0)
        XCTAssertEqual(historySpy.events.count, 0)
        XCTAssertEqual(vm.statuses[monitor.id], .up(statusCode: 200, responseTimeMs: 10, checkedAt: previousCheckedAt))
    }

    func testChecksStillRunOfflineWhenPauseWhenOfflineIsNever() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let historySpy = SpyHistoryStore()
        let checkedAt = Date()
        let checker = CountingChecker(.up(statusCode: 200, responseTimeMs: 44, checkedAt: checkedAt))
        var settings = AppSettings()
        settings.pausePingWhen = .never
        let store = SpyMonitorStore(monitors: [monitor], settings: settings)
        let vm = AppViewModel(
            checker: checker,
            monitorStore: store,
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications(),
            initialNetworkReachable: false,
            monitorNetworkPath: false
        )

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .manual)

        XCTAssertEqual(checker.calls, 1)
        XCTAssertEqual(historySpy.events.count, 1)
        XCTAssertEqual(vm.statuses[monitor.id], .up(statusCode: 200, responseTimeMs: 44, checkedAt: checkedAt))
    }

    func testWebhookTriggeredOnUpToDownTransition() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let webhookSpy = SpyWebhookDispatcher()
        let vm = AppViewModel(
            checker: StaticChecker(.down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 99, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: SpyHistoryStore(),
            webhookDispatcher: webhookSpy,
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )
        vm.settings.webhookConfigs = [
            WebhookConfig(
                name: "Test",
                isEnabled: true,
                url: "https://example.com/hook",
                sendOn: .alerting,
                scope: .allSites
            )
        ]
        vm.settings.webhookEnabled = true
        vm.statuses[monitor.id] = .up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(webhookSpy.events.count, 1)
        XCTAssertEqual(webhookSpy.events.first?.status, "down")
    }

    func testWebhookRecoveryTriggeredWhenConfigured() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let webhookSpy = SpyWebhookDispatcher()
        let checker = SequenceChecker([
            .down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 30, checkedAt: Date()),
            .up(statusCode: 200, responseTimeMs: 22, checkedAt: Date())
        ])
        let vm = AppViewModel(
            checker: checker,
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: SpyHistoryStore(),
            webhookDispatcher: webhookSpy,
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )
        vm.settings.webhookConfigs = [
            WebhookConfig(
                name: "Test",
                isEnabled: true,
                url: "https://example.com/hook",
                sendOn: .alertingAndRecovery,
                scope: .allSites
            )
        ]

        // First check transitions into alerting state and dispatches a down webhook.
        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        // Second check recovers and dispatches an up webhook.
        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(webhookSpy.events.count, 2)
        XCTAssertEqual(webhookSpy.events.map(\.status), ["down", "up"])
    }

    func testWebhookNotTriggeredWhenScopeIsSelectedSitesAndMonitorNotIncluded() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let webhookSpy = SpyWebhookDispatcher()
        let vm = AppViewModel(
            checker: StaticChecker(.down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 99, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: SpyHistoryStore(),
            webhookDispatcher: webhookSpy,
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )
        vm.settings.webhookEnabled = true
        vm.settings.webhookConfigs = [
            WebhookConfig(
                name: "Selected only",
                isEnabled: true,
                url: "https://example.com/hook",
                sendOn: .alerting,
                scope: .selectedSites,
                monitorIDs: [UUID()]
            )
        ]
        vm.statuses[monitor.id] = .up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(webhookSpy.events.count, 0)
    }

    func testWebhookDoesNotSendRecoveryWhenSendOnAlertingOnly() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let webhookSpy = SpyWebhookDispatcher()
        let checker = SequenceChecker([
            .down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 30, checkedAt: Date()),
            .up(statusCode: 200, responseTimeMs: 22, checkedAt: Date())
        ])
        let vm = AppViewModel(
            checker: checker,
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: SpyHistoryStore(),
            webhookDispatcher: webhookSpy,
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )
        vm.settings.webhookEnabled = true
        vm.settings.webhookConfigs = [
            WebhookConfig(
                name: "Alerting only",
                isEnabled: true,
                url: "https://example.com/hook",
                sendOn: .alerting,
                scope: .allSites
            )
        ]

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)
        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(webhookSpy.events.count, 1)
        XCTAssertEqual(webhookSpy.events.first?.status, "down")
    }

    func testOrderedTimelinesFollowMonitorOrder() {
        let monitorA = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "Alpha")
        let monitorB = SiteMonitor(url: URL(string: "https://b.com")!, displayName: "Beta")
        let timelines = [
            HistoryViewModel.SiteUptimeTimeline(siteName: monitorA.nameOrHost, uptimePercentage: 100, blocks: []),
            HistoryViewModel.SiteUptimeTimeline(siteName: monitorB.nameOrHost, uptimePercentage: 50, blocks: [])
        ]

        let ordered = HistoryReportsView.orderedTimelines(timelines, using: [monitorB, monitorA])

        XCTAssertEqual(ordered.map(\.siteName), [monitorB.nameOrHost, monitorA.nameOrHost])
    }

    func testWebhookDispatcherReceivesStatusCodeAndResponseMsForDownTransition() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let webhookSpy = SpyWebhookDispatcher()
        let vm = AppViewModel(
            checker: StaticChecker(.down(reason: "HTTP 503", statusCode: 503, responseTimeMs: 87, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: SpyHistoryStore(),
            webhookDispatcher: webhookSpy,
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )
        vm.settings.webhookConfigs = [
            WebhookConfig(
                name: "Test",
                isEnabled: true,
                url: "https://example.com/hook",
                sendOn: .alerting,
                scope: .allSites
            )
        ]
        vm.statuses[monitor.id] = .up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(webhookSpy.events.count, 1)
        XCTAssertEqual(webhookSpy.events.first?.status, "down")
        XCTAssertEqual(webhookSpy.events.first?.statusCode, 503)
        XCTAssertEqual(webhookSpy.events.first?.responseMs, 87)
    }

    func testWebhookDispatcherReceivesStatusCodeAndResponseMsForRecoveryTransition() async {
        let monitor = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let webhookSpy = SpyWebhookDispatcher()
        let checker = SequenceChecker([
            .down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 30, checkedAt: Date()),
            .up(statusCode: 200, responseTimeMs: 22, checkedAt: Date())
        ])
        let vm = AppViewModel(
            checker: checker,
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: SpyHistoryStore(),
            webhookDispatcher: webhookSpy,
            launchAtLogin: SpyLaunchAtLogin(),
            notifications: SpyNotifications()
        )
        vm.settings.webhookConfigs = [
            WebhookConfig(
                name: "Test",
                isEnabled: true,
                url: "https://example.com/hook",
                sendOn: .alertingAndRecovery,
                scope: .allSites
            )
        ]

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)
        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(webhookSpy.events.count, 2)
        XCTAssertEqual(webhookSpy.events.map(\.status), ["down", "up"])
        XCTAssertEqual(webhookSpy.events.last?.statusCode, 200)
        XCTAssertEqual(webhookSpy.events.last?.responseMs, 22)
    }
}

private final class SpyMonitorStore: MonitorStoreProtocol {
    private(set) var monitors: [SiteMonitor]
    private(set) var settings: AppSettings

    private(set) var savedMonitorsCalls = 0
    private(set) var savedSettingsCalls = 0
    private(set) var lastSavedSettings: AppSettings?

    init(monitors: [SiteMonitor], settings: AppSettings = AppSettings()) {
        self.monitors = monitors
        self.settings = settings
    }

    func loadMonitors() -> [SiteMonitor] { monitors }

    func saveMonitors(_ monitors: [SiteMonitor]) {
        savedMonitorsCalls += 1
        self.monitors = monitors
    }

    func loadSettings() -> AppSettings { settings }

    func saveSettings(_ settings: AppSettings) {
        savedSettingsCalls += 1
        self.settings = settings
        self.lastSavedSettings = settings
    }
}

private final class SpyHistoryStore: HistoryStoreProtocol {
    private(set) var events: [HistoryEvent] = []

    func loadEvents() -> [HistoryEvent] { events }

    func append(_ event: HistoryEvent, retentionPolicy: HistoryRetentionPolicy, maxEvents: Int) {
        events.append(event)
    }

    func replaceAll(with events: [HistoryEvent]) {
        self.events = events
    }

    func clear() {
        events = []
    }

    func delete(eventID: UUID) {
        events.removeAll { $0.id == eventID }
    }
}

private final class SpyLaunchAtLogin: LaunchAtLoginControlling {
    private(set) var lastValue: Bool?

    func setEnabled(_ enabled: Bool) {
        lastValue = enabled
    }
}

private struct SpyNotifications: NotificationDispatching {
    func send(title: String, body: String) {}
}

private final class SpyWebhookDispatcher: WebhookDispatching {
    private(set) var events: [WebhookTransitionEvent] = []
    func sendTransition(event: WebhookTransitionEvent, config: WebhookConfig) {
        events.append(event)
    }
}

private struct StaticChecker: SiteChecking {
    let status: SiteStatus

    init(_ status: SiteStatus) {
        self.status = status
    }

    func check(_ monitor: SiteMonitor) async -> SiteCheckResult {
        SiteCheckResult(status: status, methodUsed: monitor.method)
    }
}

private final class SequenceChecker: SiteChecking {
    private var statuses: [SiteStatus]

    init(_ statuses: [SiteStatus]) {
        self.statuses = statuses
    }

    func check(_ monitor: SiteMonitor) async -> SiteCheckResult {
        let next = statuses.isEmpty
            ? .up(statusCode: 200, responseTimeMs: 1, checkedAt: Date())
            : statuses.removeFirst()
        return SiteCheckResult(status: next, methodUsed: monitor.method)
    }
}

private final class CountingChecker: SiteChecking {
    private(set) var calls = 0
    private let status: SiteStatus

    init(_ status: SiteStatus) {
        self.status = status
    }

    func check(_ monitor: SiteMonitor) async -> SiteCheckResult {
        calls += 1
        return SiteCheckResult(status: status, methodUsed: monitor.method)
    }
}
