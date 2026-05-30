import Foundation
import ServiceManagement

protocol LaunchAtLoginControlling {
    func setEnabled(_ enabled: Bool)
}

struct LaunchAtLoginService: LaunchAtLoginControlling {
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Keep failures non-fatal; setting remains best-effort.
        }
    }
}
