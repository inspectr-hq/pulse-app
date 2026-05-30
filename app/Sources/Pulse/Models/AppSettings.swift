import Foundation

enum MenuBarIconColorMode: String, Codable, CaseIterable, Identifiable {
    case always
    case onlyWhenFailing
    case never

    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var pingIntervalSeconds: Int = 900
    var launchAtLogin: Bool = false
    var menuMaxItems: Int = 50
    var showMethodInMenu: Bool = true
    var showResponseTimeInMenu: Bool = true
    var showLastCheckedInMenu: Bool = true
    var showStatusCodeInMenu: Bool = true
    var menuBarIconColorMode: MenuBarIconColorMode = .always
    var historyRetentionMaxEvents: Int = 5000
}
