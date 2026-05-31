import XCTest
@testable import Pulse

@MainActor
final class OverallStatusTests: XCTestCase {
    func testNoEnabledSitesIsNeutral() {
        let vm = makeVM(monitors: [WebsiteMonitor(url: URL(string: "https://a.com")!, isEnabled: false)])
        XCTAssertEqual(vm.overallStatus, .neutral)
    }

    func testEnabledUnknownSitesYieldUnknownOverall() {
        let vm = makeVM(monitors: [WebsiteMonitor(url: URL(string: "https://a.com")!, isEnabled: true)])
        XCTAssertEqual(vm.overallStatus, .unknown)
    }

    func testDownDominatesOverallStatus() {
        let up = WebsiteMonitor(url: URL(string: "https://a.com")!, isEnabled: true)
        let down = WebsiteMonitor(url: URL(string: "https://b.com")!, isEnabled: true)
        let vm = makeVM(monitors: [up, down])

        vm.statuses[up.id] = .up(statusCode: 200, responseTimeMs: 100, checkedAt: Date())
        vm.statuses[down.id] = .down(reason: "HTTP 500", statusCode: 500, responseTimeMs: 99, checkedAt: Date())

        XCTAssertEqual(vm.overallStatus, .down)
    }

    func testCheckingBeatsUpWhenNoDown() {
        let a = WebsiteMonitor(url: URL(string: "https://a.com")!, isEnabled: true)
        let b = WebsiteMonitor(url: URL(string: "https://b.com")!, isEnabled: true)
        let vm = makeVM(monitors: [a, b])

        vm.statuses[a.id] = .up(statusCode: 200, responseTimeMs: 100, checkedAt: Date())
        vm.statuses[b.id] = .checking

        XCTAssertEqual(vm.overallStatus, .checking)
    }

    func testPausedSitesDoNotCountAsUpOrDown() {
        let enabled = WebsiteMonitor(url: URL(string: "https://a.com")!, isEnabled: true)
        let paused = WebsiteMonitor(url: URL(string: "https://b.com")!, isEnabled: false)
        let vm = makeVM(monitors: [enabled, paused])

        vm.statuses[enabled.id] = .unknown
        vm.statuses[paused.id] = .paused

        XCTAssertEqual(vm.overallStatus, .unknown)
    }

    private func makeVM(monitors: [WebsiteMonitor]) -> AppViewModel {
        AppViewModel(
            checker: FakeChecker(),
            monitorStore: FakeMonitorStore(monitors: monitors),
            historyStore: FakeHistoryStore(),
            launchAtLogin: FakeLaunchAtLogin()
        )
    }
}

private final class FakeMonitorStore: MonitorStoreProtocol {
    private var storedMonitors: [WebsiteMonitor]
    private var storedSettings = AppSettings()

    init(monitors: [WebsiteMonitor]) {
        self.storedMonitors = monitors
    }

    func loadMonitors() -> [WebsiteMonitor] { storedMonitors }
    func saveMonitors(_ monitors: [WebsiteMonitor]) { storedMonitors = monitors }
    func loadSettings() -> AppSettings { storedSettings }
    func saveSettings(_ settings: AppSettings) { storedSettings = settings }
}

private final class FakeHistoryStore: HistoryStoreProtocol {
    func loadEvents() -> [HistoryEvent] { [] }
    func append(_ event: HistoryEvent, retentionPolicy: HistoryRetentionPolicy, maxEvents: Int) {}
    func clear() {}
}

private struct FakeLaunchAtLogin: LaunchAtLoginControlling {
    func setEnabled(_ enabled: Bool) {}
}

private struct FakeChecker: WebsiteChecking {
    func check(_ monitor: WebsiteMonitor) async -> WebsiteCheckResult {
        WebsiteCheckResult(status: .up(statusCode: 200, responseTimeMs: 1, checkedAt: Date()), methodUsed: monitor.method)
    }
}
