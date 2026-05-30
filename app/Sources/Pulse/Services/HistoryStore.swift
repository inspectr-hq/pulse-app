import Foundation

protocol HistoryStoreProtocol {
    func loadEvents() -> [HistoryEvent]
    func append(_ event: HistoryEvent, maxEvents: Int)
    func clear()
}

final class HistoryStore: HistoryStoreProtocol {
    private let fileURL: URL
    private let fm: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fm = fileManager
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    init(fileManager: FileManager = .default) {
        self.fm = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pulse", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("history.json")
    }

    func loadEvents() -> [HistoryEvent] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([HistoryEvent].self, from: data)) ?? []
    }

    func append(_ event: HistoryEvent, maxEvents: Int) {
        var events = loadEvents()
        events.append(event)
        if events.count > maxEvents {
            events = Array(events.suffix(maxEvents))
        }
        persist(events)
    }

    func clear() {
        persist([])
    }

    private func persist(_ events: [HistoryEvent]) {
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
