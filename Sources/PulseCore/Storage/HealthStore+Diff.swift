import Foundation
import SQLite3

extension HealthStore {
    /// Returns the closest snapshot to the given date, plus top process names from that time.
    public func getSnapshotNear(date: Date) throws -> (snapshot: HistoryPoint, processes: [String])? {
        let target = date.timeIntervalSince1970
        // Find closest snapshot by minimum absolute distance to target timestamp
        let sql = """
        SELECT id, timestamp, cpu_user + cpu_system,
               CAST(mem_used AS REAL) / CAST(mem_total AS REAL) * 100.0,
               swap_used,
               CAST(disk_used AS REAL) / CAST(disk_total AS REAL) * 100.0,
               battery_percent, thermal_state, load_1m, health_score
        FROM snapshots
        ORDER BY ABS(timestamp - ?) ASC
        LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, target)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let snapshotId = sqlite3_column_int64(stmt, 0)
        let scoreVal: Int? = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 9))
        let point = HistoryPoint(
            timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            cpuUsage: sqlite3_column_double(stmt, 2),
            memoryUsage: sqlite3_column_double(stmt, 3),
            swapUsed: UInt64(sqlite3_column_int64(stmt, 4)),
            diskUsage: sqlite3_column_double(stmt, 5),
            batteryPercent: Int(sqlite3_column_int(stmt, 6)),
            thermalState: String(cString: sqlite3_column_text(stmt, 7)),
            load1m: sqlite3_column_double(stmt, 8),
            healthScore: scoreVal
        )

        // Get top process names for that snapshot
        let procSQL = "SELECT DISTINCT name FROM top_processes WHERE snapshot_id = ? ORDER BY cpu_percent DESC"
        var procStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, procSQL, -1, &procStmt, nil) == SQLITE_OK else {
            throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(procStmt) }
        sqlite3_bind_int64(procStmt, 1, snapshotId)

        var processes: [String] = []
        while sqlite3_step(procStmt) == SQLITE_ROW {
            processes.append(String(cString: sqlite3_column_text(procStmt, 0)))
        }

        return (snapshot: point, processes: processes)
    }
}