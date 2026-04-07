import Foundation
import SQLite3

extension HealthStore {

    // MARK: - Changelog Table Creation

    /// Create the changelog and system_state tables if they do not exist.
    /// Called lazily on first changelog operation, not during open().
    public func createChangelogTables() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS system_changelog (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                category TEXT NOT NULL,
                action TEXT NOT NULL,
                item TEXT NOT NULL,
                details TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_changelog_timestamp ON system_changelog(timestamp);

            CREATE TABLE IF NOT EXISTS system_state (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Changelog Entries

    /// Save a single change entry to the system_changelog table.
    public func saveChangelogEntry(_ entry: ChangelogMonitor.ChangeEntry) throws {
        let sql = "INSERT INTO system_changelog (timestamp, category, action, item, details) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let formatter = ISO8601DateFormatter()
        let ts = formatter.string(from: entry.timestamp)

        sqlite3_bind_text(stmt, 1, (ts as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (entry.category.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (entry.action.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (entry.item as NSString).utf8String, -1, nil)
        if let details = entry.details {
            sqlite3_bind_text(stmt, 5, (details as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 5)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    /// Get changelog entries from the last N days.
    public func getChangelog(days: Int = 30) throws -> [ChangelogMonitor.ChangeEntry] {
        let formatter = ISO8601DateFormatter()
        let since = Date().addingTimeInterval(-Double(days) * 86400)
        let sinceStr = formatter.string(from: since)

        let sql = "SELECT timestamp, category, action, item, details FROM system_changelog WHERE timestamp >= ? ORDER BY timestamp DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (sinceStr as NSString).utf8String, -1, nil)

        var results: [ChangelogMonitor.ChangeEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let tsStr = String(cString: sqlite3_column_text(stmt, 0))
            let catStr = String(cString: sqlite3_column_text(stmt, 1))
            let actStr = String(cString: sqlite3_column_text(stmt, 2))
            let item = String(cString: sqlite3_column_text(stmt, 3))
            let details: String? = sqlite3_column_text(stmt, 4).map { String(cString: $0) }

            guard let timestamp = formatter.date(from: tsStr),
                  let category = ChangelogMonitor.Category(rawValue: catStr),
                  let action = ChangelogMonitor.Action(rawValue: actStr) else {
                continue
            }

            results.append(ChangelogMonitor.ChangeEntry(
                timestamp: timestamp,
                category: category,
                action: action,
                item: item,
                details: details
            ))
        }

        return results
    }

    // MARK: - System State

    /// Save the full system state as JSON in the system_state table.
    public func saveSystemState(_ state: ChangelogMonitor.SystemState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        guard let json = String(data: data, encoding: .utf8) else {
            throw HKStoreError.query("Failed to encode system state to JSON")
        }

        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())

        let sql = "INSERT OR REPLACE INTO system_state (key, value, updated_at) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let key = "last_system_state"
        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (json as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (now as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    /// Load the last saved system state from the system_state table.
    public func getLastSystemState() throws -> ChangelogMonitor.SystemState? {
        let sql = "SELECT value FROM system_state WHERE key = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let key = "last_system_state"
        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        let json = String(cString: sqlite3_column_text(stmt, 0))
        guard let data = json.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChangelogMonitor.SystemState.self, from: data)
    }
}