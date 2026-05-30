import Foundation

enum HistoryTrigger: String, Codable, Equatable {
    case automatic
    case manual
}

struct HistoryEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let monitorID: UUID
    let monitorName: String
    let url: String
    let method: String
    let status: String
    let statusCode: Int?
    let durationMs: Int?
    let reason: String?
    let trigger: HistoryTrigger

    init(
        id: UUID = UUID(),
        timestamp: Date,
        monitorID: UUID,
        monitorName: String,
        url: String,
        method: String,
        status: String,
        statusCode: Int?,
        durationMs: Int?,
        reason: String?,
        trigger: HistoryTrigger
    ) {
        self.id = id
        self.timestamp = timestamp
        self.monitorID = monitorID
        self.monitorName = monitorName
        self.url = url
        self.method = method
        self.status = status
        self.statusCode = statusCode
        self.durationMs = durationMs
        self.reason = reason
        self.trigger = trigger
    }
}
