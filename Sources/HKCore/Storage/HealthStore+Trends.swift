import Foundation
import SQLite3

extension HealthStore {
    public struct TrendDataPoint: Sendable {
        public let timestamp: Date
        public let cpuUsage: Double
        public let memUsage: Double
        public let diskUsage: Double
        public let swapUsed: Int64
        public let batteryCycles: Int?
        public let healthScore: Int?
    }

    public func getTrendData(days: Int = 30) throws -> [TrendDataPoint] {
        let since = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        let sql = """
        SELECT timestamp, cpu_user + cpu_system,
               CAST(mem_used AS REAL) / CAST(mem_total AS REAL) * 100.0,
               CAST(disk_used AS REAL) / CAST(disk_total AS REAL) * 100.0,
               swap_used, battery_percent, health_score
        FROM snapshots WHERE timestamp > ? ORDER BY timestamp ASC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, since)
        var results: [TrendDataPoint] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let scoreVal: Int? = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 6))
            results.append(TrendDataPoint(
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                cpuUsage: sqlite3_column_double(stmt, 1),
                memUsage: sqlite3_column_double(stmt, 2),
                diskUsage: sqlite3_column_double(stmt, 3),
                swapUsed: sqlite3_column_int64(stmt, 4),
                batteryCycles: nil,
                healthScore: scoreVal
            ))
        }
        return results
    }
}