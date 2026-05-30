import SwiftUI
import AppKit

@main
struct UptimeMenuBarApp: App {
    @StateObject private var appVM = AppViewModel()
    
    init() {
        DispatchQueue.main.async {
            if let icon = NSImage(named: "AppIcon") {
                NSApp.applicationIconImage = icon
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appVM)
        } label: {
            Image(nsImage: menuBarStatusImage(for: appVM.overallStatus))
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

    private func menuBarStatusImage(for status: OverallStatus) -> NSImage {
        let symbolName = iconName(for: status)
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()

        let nsColor = NSColor(iconColor(for: status))
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: nsColor)
        let colored = base.withSymbolConfiguration(colorConfig) ?? base
        colored.isTemplate = false
        return colored
    }
}
