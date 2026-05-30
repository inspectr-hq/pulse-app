import Foundation

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
    var menuMaxItems: Int = 50
    var showMethodInMenu: Bool = true
    var showResponseTimeInMenu: Bool = true
    var showLastCheckedInMenu: Bool = true
    var showStatusCodeInMenu: Bool = true
    var menuBarIconColorMode: MenuBarIconColorMode = .always
    var historyRetentionMaxEvents: Int = 5000
}
