import SwiftUI

@main
struct UptimeMenuBarApp: App {
    @StateObject private var appVM = AppViewModel()

    var body: some Scene {
        MenuBarExtra("Pulse", systemImage: iconName(for: appVM.overallStatus)) {
            MenuBarContentView()
                .environmentObject(appVM)
        }

        Window("Site Manager", id: "site-manager") {
            SiteManagerView()
                .environmentObject(appVM)
                .frame(minWidth: 900, minHeight: 520)
        }

        Window("History Logs", id: "history") {
            HistoryView()
                .environmentObject(appVM)
                .frame(minWidth: 900, minHeight: 520)
        }

        Settings {
            SettingsView()
                .environmentObject(appVM)
        }
    }

    private func iconName(for status: OverallStatus) -> String {
        switch status {
        case .neutral: return "circle.dashed"
        case .unknown: return "questionmark.circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .up: return "checkmark.circle.fill"
        case .down: return "xmark.circle.fill"
        }
    }
}
