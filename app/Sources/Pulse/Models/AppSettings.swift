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

struct AppSettings: Codable, Equatable {
    var pingIntervalSeconds: Int = 900
    var launchAtLogin: Bool = false
    var showAlertBadgeOnDockIcon: Bool = true
    var enableLogs: Bool = true
    var pausePingWhen: PausePingMode = .offline
    var staggerRequestsSeconds: Int = 0
    var failuresToAlert: Int = 1
    var defaultThresholdMs: Int = 2000
    var defaultMethod: HTTPMethod = .head
    var statusColorUp = CodableColor(red: 0.2, green: 0.75, blue: 0.26, alpha: 1.0)
    var statusColorSlow = CodableColor(red: 0.95, green: 0.77, blue: 0.05, alpha: 1.0)
    var statusColorFailure = CodableColor(red: 0.96, green: 0.24, blue: 0.2, alpha: 1.0)
    var statusColorOffline = CodableColor(red: 0.57, green: 0.59, blue: 0.62, alpha: 1.0)
    var menuMaxItems: Int = 50
    var showMethodInMenu: Bool = true
    var showResponseTimeInMenu: Bool = true
    var showLastCheckedInMenu: Bool = true
    var showStatusCodeInMenu: Bool = true
    var menuBarIconColorMode: MenuBarIconColorMode = .always
    var webhookEnabled: Bool = false
    var webhookURL: String = ""
    var webhookMethod: HTTPMethod = .post
    var webhookSendOn: WebhookSendOn = .alerting
    var webhookPayloadTemplate: String = "{\"message\":\"$MESSAGE\",\"monitor\":\"$MONITOR\",\"status\":\"$STATUS\",\"url\":\"$URL\",\"trigger\":\"$TRIGGER\"}"
    var webhookMaxRetries: Int = 3
    var webhookInitialBackoffSeconds: Double = 1.0
    var historyRetentionMaxEvents: Int = 5000
}
