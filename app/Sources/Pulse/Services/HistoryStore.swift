import Foundation
import SQLite3

struct HistoryQuery {
    enum Status {
        case up
        case down
    }

    enum Order {
        case ascending
        case descending

        var sql: String {
            switch self {
            case .ascending: return "ASC"
            case .descending: return "DESC"
            }
        }
    }

    static let all = HistoryQuery()

    var search: String?
    var monitorID: UUID?
    var monitorName: String?
    var status: Status?
    var since: Date?
    var until: Date?

    init(
        search: String? = nil,
        monitorID: UUID? = nil,
        monitorName: String? = nil,
        status: Status? = nil,
        since: Date? = nil,
        until: Date? = nil
    ) {
        self.search = search
        self.monitorID = monitorID
        self.monitorName = monitorName
        self.status = status
        self.since = since
        self.until = until
    }
}

struct HistoryAggregate: Equatable {
    let sampleCount: Int
    let successCount: Int
    let latencySampleCount: Int
    let averageLatencyMs: Int
    let peakLatencyMs: Int
}

struct HistoryTrackingValue: Equatable {
    let label: String
    let value: String
    let firstDetectedAt: Date
}

struct HistoryPerformanceBucket: Equatable {
    let index: Int
    let sampleCount: Int
    let minMs: Int
    let averageMs: Int
    let maxMs: Int
}

struct HistoryUptimeBucket: Equatable {
    let index: Int
    let sampleCount: Int
    let successCount: Int
}

protocol HistoryStoreProtocol {
    func loadEvents() -> [HistoryEvent]
    func queryEvents(matching query: HistoryQuery, order: HistoryQuery.Order, limit: Int?) -> [HistoryEvent]
    func aggregate(matching query: HistoryQuery) -> HistoryAggregate
    func percentileLatency(_ percentile: Double, matching query: HistoryQuery) -> Int?
    func trackingValues(for monitorName: String) -> [HistoryTrackingValue]
    func monitorNames() -> [String]
    func performanceBuckets(matching query: HistoryQuery, start: Date, end: Date, bucketCount: Int) -> [HistoryPerformanceBucket]
    func uptimeBuckets(matching query: HistoryQuery, start: Date, end: Date, bucketCount: Int) -> [HistoryUptimeBucket]
    func append(_ event: HistoryEvent, retentionPolicy: HistoryRetentionPolicy, maxEvents: Int)
    func merge(_ events: [HistoryEvent], retentionPolicy: HistoryRetentionPolicy, maxEvents: Int)
    func replaceAll(with events: [HistoryEvent])
    func delete(eventID: UUID)
    func clear()
}

extension HistoryStoreProtocol {
    func queryEvents(matching query: HistoryQuery, order: HistoryQuery.Order, limit: Int?) -> [HistoryEvent] {
        let search = query.search?.localizedLowercase
        return loadEvents()
            .filter { event in
                let searchable = [event.url, event.monitorName, event.metadataLabel ?? "", event.metadataValue ?? ""]
                    .joined(separator: "\n")
                    .localizedLowercase
                let matchesSearch = search.map { searchable.contains($0) } ?? true
                let matchesMonitorID = query.monitorID.map { event.monitorID == $0 } ?? true
                let matchesName = query.monitorName.map { event.monitorName == $0 } ?? true
                let matchesStatus: Bool
                switch query.status {
                case .none: matchesStatus = true
                case .up: matchesStatus = event.status == "OK"
                case .down: matchesStatus = event.status != "OK"
                }
        let matchesSince = query.since.map { event.timestamp >= $0 } ?? true
                let matchesUntil = query.until.map { event.timestamp < $0 } ?? true
                return matchesSearch && matchesMonitorID && matchesName && matchesStatus && matchesSince && matchesUntil
            }
            .sorted { lhs, rhs in
                switch order {
                case .ascending: return lhs.timestamp == rhs.timestamp ? lhs.id.uuidString < rhs.id.uuidString : lhs.timestamp < rhs.timestamp
                case .descending: return lhs.timestamp == rhs.timestamp ? lhs.id.uuidString > rhs.id.uuidString : lhs.timestamp > rhs.timestamp
                }
            }
            .prefix(limit ?? .max)
            .map { $0 }
    }

    func aggregate(matching query: HistoryQuery) -> HistoryAggregate {
        let events = queryEvents(matching: query, order: .ascending, limit: nil)
        let latencies = events.compactMap(\.durationMs)
        return HistoryAggregate(
            sampleCount: events.count,
            successCount: events.filter { $0.status == "OK" }.count,
            latencySampleCount: latencies.count,
            averageLatencyMs: latencies.isEmpty ? 0 : latencies.reduce(0, +) / latencies.count,
            peakLatencyMs: latencies.max() ?? 0
        )
    }

    func percentileLatency(_ percentile: Double, matching query: HistoryQuery) -> Int? {
        let values = queryEvents(matching: query, order: .ascending, limit: nil)
            .compactMap(\.durationMs)
            .sorted()
        guard !values.isEmpty else { return nil }
        let index = min(values.count - 1, max(0, Int(Double(values.count) * percentile)))
        return values[index]
    }

    func trackingValues(for monitorName: String) -> [HistoryTrackingValue] {
        let grouped = Dictionary(grouping: loadEvents().filter { event in
            event.monitorName == monitorName && !(event.metadataValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }) { event in
            let label = event.metadataLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(label.flatMap { $0.isEmpty ? nil : $0 } ?? "Tracked Value")\t\(event.metadataValue!.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return grouped.compactMap { key, events in
            let components = key.split(separator: "\t", maxSplits: 1).map(String.init)
            guard components.count == 2, let first = events.min(by: { $0.timestamp < $1.timestamp }) else { return nil }
            return HistoryTrackingValue(label: components[0], value: components[1], firstDetectedAt: first.timestamp)
        }.sorted { $0.firstDetectedAt > $1.firstDetectedAt }
    }

    func monitorNames() -> [String] {
        Set(loadEvents().map(\.monitorName)).sorted()
    }

    func performanceBuckets(matching query: HistoryQuery, start: Date, end: Date, bucketCount: Int) -> [HistoryPerformanceBucket] {
        let span = end.timeIntervalSince(start) / Double(bucketCount)
        guard bucketCount > 0, span > 0 else { return [] }
        let events = queryEvents(
            matching: HistoryQuery(search: query.search, monitorID: query.monitorID, monitorName: query.monitorName, status: query.status, since: max(query.since ?? start, start), until: min(query.until ?? end, end)),
            order: .ascending,
            limit: nil
        )
        var values = Array(repeating: [Int](), count: bucketCount)
        for event in events {
            guard let duration = event.durationMs else { continue }
            let index = max(0, min(bucketCount - 1, Int(event.timestamp.timeIntervalSince(start) / span)))
            values[index].append(duration)
        }
        return values.enumerated().compactMap { index, durations in
            guard !durations.isEmpty else { return nil }
            return HistoryPerformanceBucket(index: index, sampleCount: durations.count, minMs: durations.min()!, averageMs: durations.reduce(0, +) / durations.count, maxMs: durations.max()!)
        }
    }

    func uptimeBuckets(matching query: HistoryQuery, start: Date, end: Date, bucketCount: Int) -> [HistoryUptimeBucket] {
        let span = end.timeIntervalSince(start) / Double(bucketCount)
        guard bucketCount > 0, span > 0 else { return [] }
        let events = queryEvents(
            matching: HistoryQuery(search: query.search, monitorID: query.monitorID, monitorName: query.monitorName, status: query.status, since: max(query.since ?? start, start), until: min(query.until ?? end, end)),
            order: .ascending,
            limit: nil
        )
        var counts = Array(repeating: (sample: 0, success: 0), count: bucketCount)
        for event in events {
            let index = max(0, min(bucketCount - 1, Int(event.timestamp.timeIntervalSince(start) / span)))
            counts[index].sample += 1
            if event.status == "OK" { counts[index].success += 1 }
        }
        return counts.enumerated().compactMap { index, count in
            count.sample == 0 ? nil : HistoryUptimeBucket(index: index, sampleCount: count.sample, successCount: count.success)
        }
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private struct SQLiteBinding {
    let text: String?
    let number: Double?

    init(text: String) {
        self.text = text
        self.number = nil
    }

    init(number: Double) {
        self.text = nil
        self.number = number
    }
}

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

    func queryEvents(matching query: HistoryQuery, order: HistoryQuery.Order, limit: Int?) -> [HistoryEvent] {
        guard let database else { return [] }

        let (whereSQL, bindings) = querySQL(for: query)

        let limitSQL = limit.map { " LIMIT \(max(0, $0))" } ?? ""
        let sql = """
        SELECT id, timestamp, monitor_id, monitor_name, url, method, status,
               status_code, duration_ms, reason, trigger, metadata_label, metadata_value
        FROM events \(whereSQL)
        ORDER BY timestamp \(order.sql), id \(order.sql)\(limitSQL);
        """
        guard let statement = prepare(sql, database: database) else { return [] }
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        for binding in bindings {
            if let text = binding.text {
                guard bindText(text, to: statement, at: index) else { return [] }
            } else if let number = binding.number {
                guard sqlite3_bind_double(statement, index, number) == SQLITE_OK else { return [] }
            } else {
                sqlite3_bind_null(statement, index)
            }
            index += 1
        }

        var events: [HistoryEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let event = decodeEvent(statement) { events.append(event) }
        }
        return events
    }

    func aggregate(matching query: HistoryQuery) -> HistoryAggregate {
        guard let database else { return HistoryAggregate(sampleCount: 0, successCount: 0, latencySampleCount: 0, averageLatencyMs: 0, peakLatencyMs: 0) }
        let (whereSQL, bindings) = querySQL(for: query)
        let statementSQL = """
        SELECT COUNT(*), SUM(CASE WHEN status = 'OK' THEN 1 ELSE 0 END),
               COUNT(duration_ms), AVG(duration_ms), MAX(duration_ms)
        FROM events \(whereSQL);
        """
        guard let statement = prepare(statementSQL, database: database) else { return HistoryAggregate(sampleCount: 0, successCount: 0, latencySampleCount: 0, averageLatencyMs: 0, peakLatencyMs: 0) }
        defer { sqlite3_finalize(statement) }
        guard bind(bindings, to: statement), sqlite3_step(statement) == SQLITE_ROW else {
            return HistoryAggregate(sampleCount: 0, successCount: 0, latencySampleCount: 0, averageLatencyMs: 0, peakLatencyMs: 0)
        }
        return HistoryAggregate(
            sampleCount: Int(sqlite3_column_int64(statement, 0)),
            successCount: Int(sqlite3_column_int64(statement, 1)),
            latencySampleCount: Int(sqlite3_column_int64(statement, 2)),
            averageLatencyMs: sqlite3_column_type(statement, 3) == SQLITE_NULL ? 0 : Int(sqlite3_column_double(statement, 3)),
            peakLatencyMs: sqlite3_column_type(statement, 4) == SQLITE_NULL ? 0 : Int(sqlite3_column_int64(statement, 4))
        )
    }

    func percentileLatency(_ percentile: Double, matching query: HistoryQuery) -> Int? {
        guard let database else { return nil }
        let (whereSQL, bindings) = querySQL(for: query, additionalClause: "duration_ms IS NOT NULL")
        let countSQL = "SELECT COUNT(duration_ms) FROM events \(whereSQL);"
        guard let countStatement = prepare(countSQL, database: database), bind(bindings, to: countStatement), sqlite3_step(countStatement) == SQLITE_ROW else { return nil }
        let count = Int(sqlite3_column_int64(countStatement, 0))
        sqlite3_finalize(countStatement)
        guard count > 0 else { return nil }

        let index = min(count - 1, max(0, Int(Double(count) * percentile)))
        let valueSQL = "SELECT duration_ms FROM events \(whereSQL) ORDER BY duration_ms ASC LIMIT 1 OFFSET \(index);"
        guard let valueStatement = prepare(valueSQL, database: database), bind(bindings, to: valueStatement), sqlite3_step(valueStatement) == SQLITE_ROW else { return nil }
        defer { sqlite3_finalize(valueStatement) }
        return Int(sqlite3_column_int64(valueStatement, 0))
    }

    func trackingValues(for monitorName: String) -> [HistoryTrackingValue] {
        guard let database else { return [] }
        let (whereSQL, bindings) = querySQL(
            for: HistoryQuery(monitorName: monitorName),
            additionalClause: "TRIM(COALESCE(metadata_value, '')) <> ''"
        )
        let sql = """
        SELECT COALESCE(NULLIF(TRIM(metadata_label), ''), 'Tracked Value'),
               TRIM(metadata_value), MIN(timestamp)
        FROM events \(whereSQL)
        GROUP BY COALESCE(NULLIF(TRIM(metadata_label), ''), 'Tracked Value'), TRIM(metadata_value)
        ORDER BY MIN(timestamp) DESC;
        """
        guard let statement = prepare(sql, database: database), bind(bindings, to: statement) else { return [] }
        defer { sqlite3_finalize(statement) }

        var values: [HistoryTrackingValue] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            values.append(
                HistoryTrackingValue(
                    label: columnText(statement, 0),
                    value: columnText(statement, 1),
                    firstDetectedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
                )
            )
        }
        return values
    }

    func monitorNames() -> [String] {
        guard let database,
              let statement = prepare("SELECT DISTINCT monitor_name FROM events ORDER BY monitor_name ASC;", database: database) else { return [] }
        defer { sqlite3_finalize(statement) }

        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            names.append(columnText(statement, 0))
        }
        return names
    }

    func performanceBuckets(matching query: HistoryQuery, start: Date, end: Date, bucketCount: Int) -> [HistoryPerformanceBucket] {
        guard let database, bucketCount > 0 else { return [] }
        let span = end.timeIntervalSince(start) / Double(bucketCount)
        guard span > 0 else { return [] }
        let boundedQuery = HistoryQuery(search: query.search, monitorID: query.monitorID, monitorName: query.monitorName, status: query.status, since: max(query.since ?? start, start), until: min(query.until ?? end, end))
        let (whereSQL, bindings) = querySQL(for: boundedQuery, additionalClause: "duration_ms IS NOT NULL")
        let sql = """
        SELECT CAST((timestamp - \(start.timeIntervalSince1970)) / \(span) AS INTEGER),
               COUNT(duration_ms), MIN(duration_ms), CAST(AVG(duration_ms) AS INTEGER), MAX(duration_ms)
        FROM events \(whereSQL)
        GROUP BY 1 ORDER BY 1;
        """
        guard let statement = prepare(sql, database: database), bind(bindings, to: statement) else { return [] }
        defer { sqlite3_finalize(statement) }
        var buckets: [HistoryPerformanceBucket] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            buckets.append(HistoryPerformanceBucket(index: Int(sqlite3_column_int64(statement, 0)), sampleCount: Int(sqlite3_column_int64(statement, 1)), minMs: Int(sqlite3_column_int64(statement, 2)), averageMs: Int(sqlite3_column_int64(statement, 3)), maxMs: Int(sqlite3_column_int64(statement, 4))))
        }
        return buckets
    }

    func uptimeBuckets(matching query: HistoryQuery, start: Date, end: Date, bucketCount: Int) -> [HistoryUptimeBucket] {
        guard let database, bucketCount > 0 else { return [] }
        let span = end.timeIntervalSince(start) / Double(bucketCount)
        guard span > 0 else { return [] }
        let boundedQuery = HistoryQuery(search: query.search, monitorID: query.monitorID, monitorName: query.monitorName, status: query.status, since: max(query.since ?? start, start), until: min(query.until ?? end, end))
        let (whereSQL, bindings) = querySQL(for: boundedQuery)
        let sql = """
        SELECT CAST((timestamp - \(start.timeIntervalSince1970)) / \(span) AS INTEGER),
               COUNT(*), SUM(CASE WHEN status = 'OK' THEN 1 ELSE 0 END)
        FROM events \(whereSQL)
        GROUP BY 1 ORDER BY 1;
        """
        guard let statement = prepare(sql, database: database), bind(bindings, to: statement) else { return [] }
        defer { sqlite3_finalize(statement) }
        var buckets: [HistoryUptimeBucket] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            buckets.append(HistoryUptimeBucket(index: Int(sqlite3_column_int64(statement, 0)), sampleCount: Int(sqlite3_column_int64(statement, 1)), successCount: Int(sqlite3_column_int64(statement, 2))))
        }
        return buckets
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

    private func querySQL(for query: HistoryQuery, additionalClause: String? = nil) -> (String, [SQLiteBinding]) {
        var clauses: [String] = []
        var bindings: [SQLiteBinding] = []

        if let search = query.search, !search.isEmpty {
            clauses.append("(LOWER(url) LIKE LOWER(?) OR LOWER(monitor_name) LIKE LOWER(?) OR LOWER(COALESCE(metadata_label, '')) LIKE LOWER(?) OR LOWER(COALESCE(metadata_value, '')) LIKE LOWER(?))")
            let pattern = "%\(search)%"
            bindings.append(contentsOf: [pattern, pattern, pattern, pattern].map { SQLiteBinding(text: $0) })
        }
        if let monitorID = query.monitorID {
            clauses.append("monitor_id = ?")
            bindings.append(SQLiteBinding(text: monitorID.uuidString))
        }
        if let monitorName = query.monitorName {
            clauses.append("monitor_name = ?")
            bindings.append(SQLiteBinding(text: monitorName))
        }
        switch query.status {
        case .none:
            break
        case .up:
            clauses.append("status = ?")
            bindings.append(SQLiteBinding(text: "OK"))
        case .down:
            clauses.append("status != ?")
            bindings.append(SQLiteBinding(text: "OK"))
        }
        if let since = query.since {
            clauses.append("timestamp >= ?")
            bindings.append(SQLiteBinding(number: since.timeIntervalSince1970))
        }
        if let until = query.until {
            clauses.append("timestamp < ?")
            bindings.append(SQLiteBinding(number: until.timeIntervalSince1970))
        }
        if let additionalClause {
            clauses.append(additionalClause)
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE \(clauses.joined(separator: " AND "))"
        return (whereSQL, bindings)
    }

    private func bind(_ bindings: [SQLiteBinding], to statement: OpaquePointer) -> Bool {
        var index: Int32 = 1
        for binding in bindings {
            if let text = binding.text {
                guard bindText(text, to: statement, at: index) else { return false }
            } else if let number = binding.number {
                guard sqlite3_bind_double(statement, index, number) == SQLITE_OK else { return false }
            } else {
                sqlite3_bind_null(statement, index)
            }
            index += 1
        }
        return true
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
