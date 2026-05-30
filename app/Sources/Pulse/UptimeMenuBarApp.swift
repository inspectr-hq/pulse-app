import SwiftUI

@main
struct UptimeMenuBarApp: App {
    @StateObject private var appVM = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appVM)
        } label: {
            Image(systemName: iconName(for: appVM.overallStatus))
                .foregroundStyle(iconColor(for: appVM.overallStatus))
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

    private func iconColor(for status: OverallStatus) -> Color {
        switch appVM.settings.menuBarIconColorMode {
        case .never:
            return .primary
        case .onlyWhenFailing:
            return status == .down ? .red : .primary
        case .always:
            switch status {
            case .up: return .green
            case .down: return .red
            case .checking: return .yellow
            case .unknown, .neutral: return .gray
            }
        }
    }
}
