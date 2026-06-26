import Foundation
import SwiftUI

struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum MenuBarIconColorMode: String, Codable, CaseIterable, Identifiable {
    case always
    case onlyWhenFailing
    case never

    var id: String { rawValue }
}

enum PausePingMode: String, Codable, CaseIterable, Identifiable {
    case offline = "Offline"
    case never = "Never"

    var id: String { rawValue }
}

enum WebhookSendOn: String, Codable, CaseIterable, Identifiable {
    case alerting = "Alerting"
    case alertingAndRecovery = "Alerting and Recovery"

    var id: String { rawValue }
}

enum WebhookScope: String, Codable, CaseIterable, Identifiable {
    case allSites = "All sites"
    case selectedSites = "Selected sites"

    var id: String { rawValue }
}

struct WebhookConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "Webhook"
    var isEnabled: Bool = true
    var url: String = ""
    var method: HTTPMethod = .post
    var sendOn: WebhookSendOn = .alerting
    var payloadTemplate: String = """
    {
      "message": "$MESSAGE",
      "monitor": "$MONITOR",
      "status": "$STATUS",
      "url": "$URL",
      "trigger": "$TRIGGER",
      "status_code": "$STATUS_CODE",
      "response_ms": "$RESPONSE_MS",
      "timestamp": "$TIMESTAMP"
    }
    """
    var maxRetries: Int = 3
    var initialBackoffSeconds: Double = 1.0
    var scope: WebhookScope = .allSites
    var monitorIDs: [UUID] = []
}

enum HistoryRetentionPolicy: String, Codable, CaseIterable, Identifiable {
    case oneHour = "1h"
    case oneDay = "1d"
    case oneMonth = "1m"
    case threeMonths = "3m"
    case unlimited = "unlimited"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        case .oneMonth: return "1 month"
        case .threeMonths: return "3 months"
        case .unlimited: return "Unlimited"
        }
    }

    var cutoffDate: Date? {
        let now = Date()
        switch self {
        case .oneHour:
            return now.addingTimeInterval(-3600)
        case .oneDay:
            return now.addingTimeInterval(-86400)
        case .oneMonth:
            return now.addingTimeInterval(-30 * 86400)
        case .threeMonths:
            return now.addingTimeInterval(-90 * 86400)
        case .unlimited:
            return nil
        }
    }
}

struct PerformanceTrendMetricVisibility: Codable, Equatable {
    var showHighest: Bool = true
    var showLowest: Bool = true
    var showAverage: Bool = true
    var showP95: Bool = true
    var showP99: Bool = true

    var hasVisibleMetric: Bool {
        showHighest || showLowest || showAverage || showP95 || showP99
    }
}

struct AppSettings: Codable, Equatable {
    var pingIntervalSeconds: Int = 900
    var launchAtLogin: Bool = false
    var showAlertBadgeOnDockIcon: Bool = true
    var pausePingWhen: PausePingMode = .offline
    var staggerRequestsSeconds: Int = 0
    var failuresToAlert: Int = 1
    var defaultThresholdMs: Int = 2000
    var defaultMethod: HTTPMethod = .head
    var statusColorUp = CodableColor(red: 0.2, green: 0.75, blue: 0.26, alpha: 1.0)
    var statusColorSlow = CodableColor(red: 0.95, green: 0.77, blue: 0.05, alpha: 1.0)
    var statusColorFailure = CodableColor(red: 0.96, green: 0.24, blue: 0.2, alpha: 1.0)
    var statusColorOffline = CodableColor(red: 0.57, green: 0.59, blue: 0.62, alpha: 1.0)
    var menuMaxItems: Int = 20
    var showMethodInMenu: Bool = true
    var showResponseTimeInMenu: Bool = true
    var showLastCheckedInMenu: Bool = true
    var showStatusCodeInMenu: Bool = true
    var hidePausedSitesInMenuBar: Bool = false
    var showMenuIconStatusColor: Bool = true
    var menuBarIconColorMode: MenuBarIconColorMode = .always
    var webhookEnabled: Bool = false
    var webhookURL: String = ""
    var webhookMethod: HTTPMethod = .post
    var webhookSendOn: WebhookSendOn = .alerting
    var webhookPayloadTemplate: String = """
    {
      "message": "$MESSAGE",
      "monitor": "$MONITOR",
      "status": "$STATUS",
      "url": "$URL",
      "trigger": "$TRIGGER",
      "status_code": "$STATUS_CODE",
      "response_ms": "$RESPONSE_MS",
      "timestamp": "$TIMESTAMP"
    }
    """
    var webhookMaxRetries: Int = 3
    var webhookInitialBackoffSeconds: Double = 1.0
    var webhookConfigs: [WebhookConfig] = []
    var historyRetentionPolicy: HistoryRetentionPolicy = .oneMonth
    var performanceTrendMetricVisibility = PerformanceTrendMetricVisibility()
    // Legacy fallback cap retained for compatibility with old persisted settings.
    var historyRetentionMaxEvents: Int = 5000

    init() {}

    private enum CodingKeys: String, CodingKey {
        case pingIntervalSeconds
        case launchAtLogin
        case showAlertBadgeOnDockIcon
        case pausePingWhen
        case staggerRequestsSeconds
        case failuresToAlert
        case defaultThresholdMs
        case defaultMethod
        case statusColorUp
        case statusColorSlow
        case statusColorFailure
        case statusColorOffline
        case menuMaxItems
        case showMethodInMenu
        case showResponseTimeInMenu
        case showLastCheckedInMenu
        case showStatusCodeInMenu
        case hidePausedSitesInMenuBar
        case showMenuIconStatusColor
        case menuBarIconColorMode
        case webhookEnabled
        case webhookURL
        case webhookMethod
        case webhookSendOn
        case webhookPayloadTemplate
        case webhookMaxRetries
        case webhookInitialBackoffSeconds
        case webhookConfigs
        case historyRetentionPolicy
        case performanceTrendMetricVisibility
        case historyRetentionMaxEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()

        pingIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .pingIntervalSeconds) ?? pingIntervalSeconds
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
        showAlertBadgeOnDockIcon = try container.decodeIfPresent(Bool.self, forKey: .showAlertBadgeOnDockIcon) ?? showAlertBadgeOnDockIcon
        pausePingWhen = try container.decodeIfPresent(PausePingMode.self, forKey: .pausePingWhen) ?? pausePingWhen
        staggerRequestsSeconds = try container.decodeIfPresent(Int.self, forKey: .staggerRequestsSeconds) ?? staggerRequestsSeconds
        failuresToAlert = try container.decodeIfPresent(Int.self, forKey: .failuresToAlert) ?? failuresToAlert
        defaultThresholdMs = try container.decodeIfPresent(Int.self, forKey: .defaultThresholdMs) ?? defaultThresholdMs
        defaultMethod = try container.decodeIfPresent(HTTPMethod.self, forKey: .defaultMethod) ?? defaultMethod
        statusColorUp = try container.decodeIfPresent(CodableColor.self, forKey: .statusColorUp) ?? statusColorUp
        statusColorSlow = try container.decodeIfPresent(CodableColor.self, forKey: .statusColorSlow) ?? statusColorSlow
        statusColorFailure = try container.decodeIfPresent(CodableColor.self, forKey: .statusColorFailure) ?? statusColorFailure
        statusColorOffline = try container.decodeIfPresent(CodableColor.self, forKey: .statusColorOffline) ?? statusColorOffline
        menuMaxItems = try container.decodeIfPresent(Int.self, forKey: .menuMaxItems) ?? menuMaxItems
        showMethodInMenu = try container.decodeIfPresent(Bool.self, forKey: .showMethodInMenu) ?? showMethodInMenu
        showResponseTimeInMenu = try container.decodeIfPresent(Bool.self, forKey: .showResponseTimeInMenu) ?? showResponseTimeInMenu
        showLastCheckedInMenu = try container.decodeIfPresent(Bool.self, forKey: .showLastCheckedInMenu) ?? showLastCheckedInMenu
        showStatusCodeInMenu = try container.decodeIfPresent(Bool.self, forKey: .showStatusCodeInMenu) ?? showStatusCodeInMenu
        hidePausedSitesInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .hidePausedSitesInMenuBar) ?? hidePausedSitesInMenuBar
        showMenuIconStatusColor = try container.decodeIfPresent(Bool.self, forKey: .showMenuIconStatusColor) ?? showMenuIconStatusColor
        menuBarIconColorMode = try container.decodeIfPresent(MenuBarIconColorMode.self, forKey: .menuBarIconColorMode) ?? menuBarIconColorMode
        webhookEnabled = try container.decodeIfPresent(Bool.self, forKey: .webhookEnabled) ?? webhookEnabled
        webhookURL = try container.decodeIfPresent(String.self, forKey: .webhookURL) ?? webhookURL
        webhookMethod = try container.decodeIfPresent(HTTPMethod.self, forKey: .webhookMethod) ?? webhookMethod
        webhookSendOn = try container.decodeIfPresent(WebhookSendOn.self, forKey: .webhookSendOn) ?? webhookSendOn
        webhookPayloadTemplate = try container.decodeIfPresent(String.self, forKey: .webhookPayloadTemplate) ?? webhookPayloadTemplate
        webhookMaxRetries = try container.decodeIfPresent(Int.self, forKey: .webhookMaxRetries) ?? webhookMaxRetries
        webhookInitialBackoffSeconds = try container.decodeIfPresent(Double.self, forKey: .webhookInitialBackoffSeconds) ?? webhookInitialBackoffSeconds
        webhookConfigs = try container.decodeIfPresent([WebhookConfig].self, forKey: .webhookConfigs) ?? webhookConfigs
        historyRetentionPolicy = try container.decodeIfPresent(HistoryRetentionPolicy.self, forKey: .historyRetentionPolicy) ?? historyRetentionPolicy
        performanceTrendMetricVisibility = try container.decodeIfPresent(
            PerformanceTrendMetricVisibility.self,
            forKey: .performanceTrendMetricVisibility
        ) ?? performanceTrendMetricVisibility
        historyRetentionMaxEvents = try container.decodeIfPresent(Int.self, forKey: .historyRetentionMaxEvents) ?? historyRetentionMaxEvents
    }
}
