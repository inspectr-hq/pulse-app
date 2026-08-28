import Foundation
import SQLite3

protocol HistoryStoreProtocol {
    func loadEvents() -> [HistoryEvent]
    func append(_ event: HistoryEvent, retentionPolicy: HistoryRetentionPolicy, maxEvents: Int)
    func merge(_ events: [HistoryEvent], retentionPolicy: HistoryRetentionPolicy, maxEvents: Int)
    func replaceAll(with events: [HistoryEvent])
    func delete(eventID: UUID)
    func clear()
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class HistoryStore: HistoryStoreProtocol {
    static let databaseFileName = "history.sqlite"
    static let legacyFileName = "history.json"

    private let fileURL: URL
    private let legacyFileURL: URL
    private let fm: FileManager
    private var database: OpaquePointer?
    private let decoder: JSONDecoder

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fm = fileManager
        self.fileURL = fileURL
        self.legacyFileURL = fileURL.deletingPathExtension().appendingPathExtension("json")
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        openAndMigrate()
    }

    convenience init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pulse", isDirectory: true)
        self.init(fileURL: dir.appendingPathComponent(Self.databaseFileName), fileManager: fileManager)
    }

    deinit { sqlite3_close(database) }

    func loadEvents() -> [HistoryEvent] {
        guard let database,
              let statement = prepare("""
                SELECT id, timestamp, monitor_id, monitor_name, url, method, status,
                       status_code, duration_ms, reason, trigger, metadata_label, metadata_value
                FROM events ORDER BY timestamp DESC;
                """, database: database) else { return [] }
        defer { sqlite3_finalize(statement) }

        var events: [HistoryEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let event = decodeEvent(statement) { events.append(event) }
        }
        return events
    }

    func append(_ event: HistoryEvent, retentionPolicy: HistoryRetentionPolicy, maxEvents: Int) {
        merge([event], retentionPolicy: retentionPolicy, maxEvents: maxEvents)
    }

    func merge(_ events: [HistoryEvent], retentionPolicy: HistoryRetentionPolicy, maxEvents: Int) {
        guard let database, !events.isEmpty, exec("BEGIN IMMEDIATE TRANSACTION;", database: database) else { return }
        var succeeded = true
        for event in events {
            succeeded = insert(event, database: database, ignoreDuplicate: true) && succeeded
        }
        succeeded = applyRetention(retentionPolicy: retentionPolicy, maxEvents: maxEvents, database: database) && succeeded
        _ = exec(succeeded ? "COMMIT;" : "ROLLBACK;", database: database)
    }

    func replaceAll(with events: [HistoryEvent]) {
        guard let database, exec("BEGIN IMMEDIATE TRANSACTION;", database: database) else { return }
        var succeeded = exec("DELETE FROM events;", database: database)
        for event in events {
            succeeded = insert(event, database: database, ignoreDuplicate: false) && succeeded
        }
        _ = exec(succeeded ? "COMMIT;" : "ROLLBACK;", database: database)
    }

    func delete(eventID: UUID) {
        guard let database, let statement = prepare("DELETE FROM events WHERE id = ?;", database: database) else { return }
        defer { sqlite3_finalize(statement) }
        _ = bindText(eventID.uuidString, to: statement, at: 1)
        _ = sqlite3_step(statement)
    }

    func clear() {
        if let database { _ = exec("DELETE FROM events;", database: database) }
    }

    private func openAndMigrate() {
        guard sqlite3_open_v2(fileURL.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(database)
            database = nil
            return
        }
        guard let database, exec("PRAGMA foreign_keys = ON;", database: database), exec(Self.schemaSQL, database: database) else { return }
        migrateLegacyJSONIfNeeded(database: database)
    }

    private func migrateLegacyJSONIfNeeded(database: OpaquePointer) {
        guard fm.fileExists(atPath: legacyFileURL.path), eventCount(database: database) == 0,
              let data = try? Data(contentsOf: legacyFileURL), let events = try? decoder.decode([HistoryEvent].self, from: data),
              exec("BEGIN IMMEDIATE TRANSACTION;", database: database) else { return }

        var succeeded = true
        for event in events { succeeded = insert(event, database: database, ignoreDuplicate: true) && succeeded }
        succeeded = succeeded && eventCount(database: database) == events.count
        _ = exec(succeeded ? "COMMIT;" : "ROLLBACK;", database: database)

        if succeeded {
            let suffix = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let backupURL = legacyFileURL.deletingPathExtension().appendingPathExtension("migrated-\(suffix).json")
            try? fm.moveItem(at: legacyFileURL, to: backupURL)
        }
    }

    private func insert(_ event: HistoryEvent, database: OpaquePointer, ignoreDuplicate: Bool) -> Bool {
        let conflict = ignoreDuplicate ? " OR IGNORE" : ""
        let sql = """
        INSERT\(conflict) INTO events
        (id, timestamp, monitor_id, monitor_name, url, method, status, status_code,
         duration_ms, reason, trigger, metadata_label, metadata_value)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        guard let statement = prepare(sql, database: database) else { return false }
        defer { sqlite3_finalize(statement) }
        _ = bindText(event.id.uuidString, to: statement, at: 1)
        sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
        _ = bindText(event.monitorID.uuidString, to: statement, at: 3)
        _ = bindText(event.monitorName, to: statement, at: 4)
        _ = bindText(event.url, to: statement, at: 5)
        _ = bindText(event.method, to: statement, at: 6)
        _ = bindText(event.status, to: statement, at: 7)
        bindOptionalInt(event.statusCode, to: statement, at: 8)
        bindOptionalInt(event.durationMs, to: statement, at: 9)
        bindOptionalText(event.reason, to: statement, at: 10)
        _ = bindText(event.trigger.rawValue, to: statement, at: 11)
        bindOptionalText(event.metadataLabel, to: statement, at: 12)
        bindOptionalText(event.metadataValue, to: statement, at: 13)
        return sqlite3_step(statement) == SQLITE_DONE
    }

    private func applyRetention(retentionPolicy: HistoryRetentionPolicy, maxEvents: Int, database: OpaquePointer) -> Bool {
        if let cutoff = retentionPolicy.cutoffDate,
           !exec("DELETE FROM events WHERE timestamp < \(cutoff.timeIntervalSince1970);", database: database) { return false }
        let safeLimit = max(1, maxEvents)
        return exec("""
            DELETE FROM events WHERE id IN (
                SELECT id FROM events ORDER BY timestamp ASC LIMIT
                MAX(0, (SELECT COUNT(*) FROM events) - \(safeLimit))
            );
            """, database: database)
    }

    private func eventCount(database: OpaquePointer) -> Int {
        guard let statement = prepare("SELECT COUNT(*) FROM events;", database: database) else { return -1 }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return -1 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func decodeEvent(_ statement: OpaquePointer) -> HistoryEvent? {
        guard let id = UUID(uuidString: columnText(statement, 0)), let monitorID = UUID(uuidString: columnText(statement, 2)),
              let trigger = HistoryTrigger(rawValue: columnText(statement, 10)) else { return nil }
        return HistoryEvent(
            id: id, timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)), monitorID: monitorID,
            monitorName: columnText(statement, 3), url: columnText(statement, 4), method: columnText(statement, 5),
            status: columnText(statement, 6), statusCode: optionalInt(statement, 7), durationMs: optionalInt(statement, 8),
            reason: optionalText(statement, 9), trigger: trigger, metadataLabel: optionalText(statement, 11), metadataValue: optionalText(statement, 12)
        )
    }

    private func prepare(_ sql: String, database: OpaquePointer) -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        return statement
    }

    private func exec(_ sql: String, database: OpaquePointer) -> Bool { sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK }

    private func bindText(_ value: String, to statement: OpaquePointer, at index: Int32) -> Bool {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient) == SQLITE_OK
    }

    private func bindOptionalText(_ value: String?, to statement: OpaquePointer, at index: Int32) {
        guard let value else { sqlite3_bind_null(statement, index); return }
        _ = bindText(value, to: statement, at: index)
    }

    private func bindOptionalInt(_ value: Int?, to statement: OpaquePointer, at index: Int32) {
        guard let value else { sqlite3_bind_null(statement, index); return }
        sqlite3_bind_int64(statement, index, sqlite3_int64(value))
    }

    private func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let raw = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: raw)
    }

    private func optionalText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : columnText(statement, index)
    }

    private func optionalInt(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, index))
    }

    private static let schemaSQL = """
    CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY NOT NULL, timestamp REAL NOT NULL, monitor_id TEXT NOT NULL,
        monitor_name TEXT NOT NULL, url TEXT NOT NULL, method TEXT NOT NULL, status TEXT NOT NULL,
        status_code INTEGER, duration_ms INTEGER, reason TEXT, trigger TEXT NOT NULL,
        metadata_label TEXT, metadata_value TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
    CREATE INDEX IF NOT EXISTS idx_events_monitor_id ON events(monitor_id);
    CREATE INDEX IF NOT EXISTS idx_events_monitor_name ON events(monitor_name);
    CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
    """
}
