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
            launchAtLogin: SpyLaunchAtLogin()
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
            launchAtLogin: SpyLaunchAtLogin()
        )

        let error = vm.addMonitor(rawURL: "", name: "Bad")

        XCTAssertNotNil(error)
        XCTAssertEqual(vm.monitors.count, 0)
        XCTAssertEqual(store.savedMonitorsCalls, 0)
    }

    func testUpdateMonitorPersistsChanges() {
        let monitor = WebsiteMonitor(url: URL(string: "https://a.com")!, displayName: "A")
        let store = SpyMonitorStore(monitors: [monitor])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin()
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
        let monitor = WebsiteMonitor(url: URL(string: "https://a.com")!, displayName: "A")
        let store = SpyMonitorStore(monitors: [monitor])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin()
        )

        vm.removeMonitor(id: monitor.id)

        XCTAssertTrue(vm.monitors.isEmpty)
        XCTAssertNil(vm.statuses[monitor.id])
        XCTAssertEqual(store.savedMonitorsCalls, 1)
    }

    func testSaveSettingsPersistsAndCallsLaunchAtLogin() {
        let launchSpy = SpyLaunchAtLogin()
        let store = SpyMonitorStore(monitors: [])
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())),
            monitorStore: store,
            historyStore: SpyHistoryStore(),
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: launchSpy
        )

        vm.settings.launchAtLogin = true
        vm.settings.pingIntervalSeconds = 120
        vm.saveSettings()

        XCTAssertEqual(store.savedSettingsCalls, 1)
        XCTAssertEqual(store.lastSavedSettings?.pingIntervalSeconds, 120)
        XCTAssertEqual(launchSpy.lastValue, true)
    }

    func testCheckWritesHistoryEventForUpResult() async {
        let monitor = WebsiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let historySpy = SpyHistoryStore()
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 88, checkedAt: Date(timeIntervalSince1970: 1_700_000_010))),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin()
        )

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .manual)

        XCTAssertEqual(historySpy.events.count, 1)
        guard let event = historySpy.events.first else {
            XCTFail("Expected history event")
            return
        }
        XCTAssertEqual(event.method, "GET")
        XCTAssertEqual(event.status, "OK")
        XCTAssertEqual(event.statusCode, 200)
        XCTAssertEqual(event.durationMs, 88)
        XCTAssertEqual(event.trigger, .manual)
    }

    func testCheckWritesHistoryEventForDownResult() async {
        let monitor = WebsiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .head)
        let historySpy = SpyHistoryStore()
        let vm = AppViewModel(
            checker: StaticChecker(.down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 55, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin()
        )

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(historySpy.events.count, 1)
        guard let event = historySpy.events.first else {
            XCTFail("Expected history event")
            return
        }
        XCTAssertEqual(event.status, "Down")
        XCTAssertEqual(event.statusCode, 500)
        XCTAssertEqual(event.trigger, .automatic)
    }

    func testPausedSiteManualCheckStaysPausedButStillLogsRealResult() async {
        let paused = WebsiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: false, method: .get)
        let historySpy = SpyHistoryStore()
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 44, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [paused]),
            historyStore: historySpy,
            webhookDispatcher: SpyWebhookDispatcher(),
            launchAtLogin: SpyLaunchAtLogin()
        )

        await vm.check(monitorID: paused.id, allowPaused: true, trigger: .manual)

        XCTAssertEqual(vm.statuses[paused.id], .paused)
        XCTAssertEqual(historySpy.events.count, 1)
        XCTAssertEqual(historySpy.events.first?.trigger, .manual)
        XCTAssertEqual(historySpy.events.first?.status, "OK")
    }

    func testWebhookTriggeredOnUpToDownTransition() async {
        let monitor = WebsiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let webhookSpy = SpyWebhookDispatcher()
        let vm = AppViewModel(
            checker: StaticChecker(.down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 99, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: SpyHistoryStore(),
            webhookDispatcher: webhookSpy,
            launchAtLogin: SpyLaunchAtLogin()
        )
        vm.settings.webhookEnabled = true
        vm.settings.webhookURL = "https://example.com/hook"
        vm.statuses[monitor.id] = .up(statusCode: 200, responseTimeMs: 10, checkedAt: Date())

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(webhookSpy.events.count, 1)
        XCTAssertEqual(webhookSpy.events.first?.status, "down")
    }

    func testWebhookRecoveryTriggeredWhenConfigured() async {
        let monitor = WebsiteMonitor(url: URL(string: "https://a.com")!, displayName: "A", isEnabled: true, method: .get)
        let webhookSpy = SpyWebhookDispatcher()
        let vm = AppViewModel(
            checker: StaticChecker(.up(statusCode: 200, responseTimeMs: 22, checkedAt: Date())),
            monitorStore: SpyMonitorStore(monitors: [monitor]),
            historyStore: SpyHistoryStore(),
            webhookDispatcher: webhookSpy,
            launchAtLogin: SpyLaunchAtLogin()
        )
        vm.settings.webhookEnabled = true
        vm.settings.webhookURL = "https://example.com/hook"
        vm.settings.webhookSendOn = .alertingAndRecovery
        vm.statuses[monitor.id] = .down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 30, checkedAt: Date())

        await vm.check(monitorID: monitor.id, allowPaused: true, trigger: .automatic)

        XCTAssertEqual(webhookSpy.events.count, 1)
        XCTAssertEqual(webhookSpy.events.first?.status, "up")
    }
}

private final class SpyMonitorStore: MonitorStoreProtocol {
    private(set) var monitors: [WebsiteMonitor]
    private(set) var settings = AppSettings()

    private(set) var savedMonitorsCalls = 0
    private(set) var savedSettingsCalls = 0
    private(set) var lastSavedSettings: AppSettings?

    init(monitors: [WebsiteMonitor]) {
        self.monitors = monitors
    }

    func loadMonitors() -> [WebsiteMonitor] { monitors }

    func saveMonitors(_ monitors: [WebsiteMonitor]) {
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

    func append(_ event: HistoryEvent, maxEvents: Int) {
        events.append(event)
    }

    func clear() {
        events = []
    }
}

private final class SpyLaunchAtLogin: LaunchAtLoginControlling {
    private(set) var lastValue: Bool?

    func setEnabled(_ enabled: Bool) {
        lastValue = enabled
    }
}

private final class SpyWebhookDispatcher: WebhookDispatching {
    private(set) var events: [WebhookTransitionEvent] = []
    func sendTransition(event: WebhookTransitionEvent, settings: AppSettings) {
        events.append(event)
    }
}

private struct StaticChecker: WebsiteChecking {
    let status: WebsiteStatus

    init(_ status: WebsiteStatus) {
        self.status = status
    }

    func check(_ monitor: WebsiteMonitor) async -> WebsiteCheckResult {
        WebsiteCheckResult(status: status, methodUsed: monitor.method)
    }
}
