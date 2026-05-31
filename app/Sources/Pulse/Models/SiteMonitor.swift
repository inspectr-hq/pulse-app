import Foundation

enum HTTPMethod: String, Codable, CaseIterable, Equatable, Identifiable {
    case head = "HEAD"
    case get = "GET"
    case post = "POST"

    var id: String { rawValue }
}

struct HeaderEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var value: String
}

struct SiteMonitor: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var displayName: String
    var isEnabled: Bool
    var method: HTTPMethod
    var body: String
    var headers: [HeaderEntry]
    var allowInsecureSSL: Bool
    var thresholdMs: Int
    var keyword: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        url: URL,
        displayName: String = "",
        isEnabled: Bool = true,
        method: HTTPMethod = .head,
        body: String = "",
        headers: [HeaderEntry] = [],
        allowInsecureSSL: Bool = false,
        thresholdMs: Int = 2000,
        keyword: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.method = method
        self.body = body
        self.headers = headers
        self.allowInsecureSSL = allowInsecureSSL
        self.thresholdMs = thresholdMs
        self.keyword = keyword
        self.createdAt = createdAt
    }

    var nameOrHost: String {
        if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }
        return url.host ?? url.absoluteString
    }
}
