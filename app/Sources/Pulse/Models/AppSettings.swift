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
    // Legacy fallback cap retained for compatibility with old persisted settings.
    var historyRetentionMaxEvents: Int = 5000
}
