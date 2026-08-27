import XCTest
@testable import Pulse

final class SettingsViewTests: XCTestCase {
    func testSettingsIncludesAboutTab() {
        XCTAssertTrue(SettingsView.Tab.allCases.contains(.about))
        XCTAssertEqual(SettingsView.Tab.about.rawValue, "About")
        XCTAssertEqual(SettingsView.Tab.about.icon, "info.circle")
    }

    func testAboutMetadataUsesExpectedAppNameAndGitHubURL() {
        XCTAssertEqual(SettingsView.appDisplayName, "Pulse")
        XCTAssertEqual(SettingsView.githubURL.absoluteString, "https://github.com/inspectr-hq/pulse-app")
        XCTAssertEqual(SettingsView.inspectrURL.absoluteString, "https://inspectr.dev")
    }

    func testPerformanceTrendMetricVisibilityDefaultsToAllVisible() throws {
        let settings = AppSettings()

        XCTAssertTrue(settings.performanceTrendMetricVisibility.showHighest)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showLowest)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showAverage)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showP95)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showP99)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.hasVisibleMetric)
    }

    func testHistoryRetentionMaxEventsUsesGenerousDefault() {
        XCTAssertEqual(AppSettings().historyRetentionMaxEvents, 100_000)
    }

    func testHistoryRetentionMaxEventsCanBePersistedInSettings() throws {
        let json = "{\"historyRetentionMaxEvents\": 250000}"

        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.historyRetentionMaxEvents, 250_000)
    }

    func testAppSettingsDecodesWithoutPerformanceTrendMetricVisibility() throws {
        let json = """
        {
          "pingIntervalSeconds": 120,
          "launchAtLogin": true,
          "defaultThresholdMs": 3000
        }
        """

        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.pingIntervalSeconds, 120)
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertEqual(settings.defaultThresholdMs, 3000)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showHighest)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showLowest)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showAverage)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showP95)
        XCTAssertTrue(settings.performanceTrendMetricVisibility.showP99)
    }

    func testUpdateCheckerComparesSemanticVersions() {
        XCTAssertEqual(AppUpdateChecker.compareVersions("0.5.5", "1.0.0"), .orderedAscending)
        XCTAssertEqual(AppUpdateChecker.compareVersions("1.0.0", "0.5.5"), .orderedDescending)
        XCTAssertEqual(AppUpdateChecker.compareVersions("1.0", "1.0.0"), .orderedSame)
        XCTAssertEqual(AppUpdateChecker.compareVersions("v1.0.0", "1.0.0"), .orderedSame)
    }

    func testUpdateCheckerNormalizesGitHubTagVersions() {
        XCTAssertEqual(AppUpdateChecker.normalizedVersion("v0.5.5"), "0.5.5")
        XCTAssertEqual(AppUpdateChecker.normalizedVersion("1.0.0"), "1.0.0")
        XCTAssertEqual(AppUpdateChecker.normalizedVersion("v1.0.0-beta.1"), "1.0.0")
    }
}
