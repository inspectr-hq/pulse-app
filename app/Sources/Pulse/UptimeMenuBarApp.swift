import SwiftUI
import AppKit

@main
struct UptimeMenuBarApp: App {
    @StateObject private var appVM = AppViewModel()
    
    init() {
        DispatchQueue.main.async {
            if let iconURL = Bundle.main.url(forResource: "AppDockIcon", withExtension: "png"),
               let icon = NSImage(contentsOf: iconURL) {
                NSApp.applicationIconImage = icon
            } else if let icon = NSImage(named: "AppIcon") {
                NSApp.applicationIconImage = icon
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appVM)
        } label: {
            Image(systemName: iconName(for: appVM.overallStatus))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor(for: appVM.overallStatus))
        }
        .menuBarExtraStyle(.window)
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
            return status == .down ? appVM.settings.statusColorFailure.color : .primary
        case .always:
            switch status {
            case .up: return appVM.settings.statusColorUp.color
            case .down: return appVM.settings.statusColorFailure.color
            case .checking: return appVM.settings.statusColorSlow.color
            case .unknown, .neutral: return appVM.settings.statusColorOffline.color
            }
        }
    }

}
