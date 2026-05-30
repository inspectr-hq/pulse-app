import Foundation

protocol MonitorStoreProtocol {
    func loadMonitors() -> [WebsiteMonitor]
    func saveMonitors(_ monitors: [WebsiteMonitor])
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}

final class MonitorStore: MonitorStoreProtocol {
    private let defaults: UserDefaults
    private let monitorsKey = "pulse.monitors"
    private let settingsKey = "pulse.settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadMonitors() -> [WebsiteMonitor] {
        guard let data = defaults.data(forKey: monitorsKey) else { return [] }
        return (try? JSONDecoder().decode([WebsiteMonitor].self, from: data)) ?? []
    }

    func saveMonitors(_ monitors: [WebsiteMonitor]) {
        if let data = try? JSONEncoder().encode(monitors) {
            defaults.set(data, forKey: monitorsKey)
        }
    }

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey) else { return AppSettings() }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }
}
