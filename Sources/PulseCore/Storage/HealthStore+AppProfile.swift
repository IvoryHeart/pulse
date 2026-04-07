import Foundation
import SQLite3

extension HealthStore {
    public struct ProcessRecord: Sendable {
        public let snapshotTimestamp: Date
        public let name: String
        public let cpuPercent: Double
        public let rssBytes: Int64

        public init(snapshotTimestamp: Date, name: String, cpuPercent: Double, rssBytes: Int64) {
            self.snapshotTimestamp = snapshotTimestamp
            self.name = name
            self.cpuPercent = cpuPercent
            self.rssBytes = rssBytes
        }
    }

    /// Get all process records from the last N days, joined with snapshot timestamps
    public func getProcessHistory(days: Int = 7) throws -> [ProcessRecord] {
        let since = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        let sql = """
        SELECT s.timestamp, p.name, p.cpu_percent, p.rss_bytes
        FROM top_processes p
        JOIN snapshots s ON p.snapshot_id = s.id
        WHERE s.timestamp > ?
        ORDER BY s.timestamp ASC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, since)

        var results: [ProcessRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let record = ProcessRecord(
                snapshotTimestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                name: String(cString: sqlite3_column_text(stmt, 1)),
                cpuPercent: sqlite3_column_double(stmt, 2),
                rssBytes: sqlite3_column_int64(stmt, 3)
            )
            results.append(record)
        }

        return results
    }
}