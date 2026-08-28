import Foundation

struct PulseBackup: Codable, Equatable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let appName: String
    let appVersion: String
    let exportedAt: Date
    let monitors: [SiteMonitor]
    let settings: AppSettings
    let history: [HistoryEvent]

    init(
        appName: String = "Pulse",
        appVersion: String = AppUpdateChecker.currentAppVersion(),
        exportedAt: Date = Date(),
        monitors: [SiteMonitor],
        settings: AppSettings,
        history: [HistoryEvent]
    ) {
        self.formatVersion = Self.currentFormatVersion
        self.appName = appName
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.monitors = monitors
        self.settings = settings
        self.history = history
    }

    func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> PulseBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Self.self, from: data)
        guard backup.formatVersion == currentFormatVersion, backup.appName == "Pulse" else {
            throw BackupError.unsupportedFormat
        }
        return backup
    }

    enum BackupError: LocalizedError {
        case unsupportedFormat

        var errorDescription: String? {
            "This file is not a supported Pulse backup."
        }
    }
}
