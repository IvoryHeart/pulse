import Foundation
import SQLite3

/// SQLite-backed storage for health snapshots.
/// Database lives at ~/.hk/health.db
public final class HealthStore {
    var db: OpaquePointer?
    public static let shared = HealthStore()

    public static var dbPath: String {
        let dir = FileManager.default.homeDirectoryForCurrentUser.path + "/.hk"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/health.db"
    }

    private init() {}

    public func open() throws {
        let path = Self.dbPath
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw HKStoreError.cannotOpen(String(cString: sqlite3_errmsg(db)))
        }
        try createTables()
    }

    public func close() {
        if let db = db {
            sqlite3_close(db)
        }
        db = nil
    }

    // MARK: - Schema

    private func createTables() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            cpu_user REAL NOT NULL,
            cpu_system REAL NOT NULL,
            cpu_idle REAL NOT NULL,
            load_1m REAL NOT NULL,
            load_5m REAL NOT NULL,
            load_15m REAL NOT NULL,
            mem_total INTEGER NOT NULL,
            mem_used INTEGER NOT NULL,
            mem_wired INTEGER NOT NULL,
            mem_compressed INTEGER NOT NULL,
            swap_used INTEGER NOT NULL,
            swap_total INTEGER NOT NULL,
            disk_total INTEGER NOT NULL,
            disk_used INTEGER NOT NULL,
            disk_available INTEGER NOT NULL,
            battery_percent INTEGER NOT NULL,
            battery_charging INTEGER NOT NULL,
            thermal_state TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_snapshots_timestamp ON snapshots(timestamp);

        CREATE TABLE IF NOT EXISTS top_processes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_id INTEGER NOT NULL,
            pid INTEGER NOT NULL,
            name TEXT NOT NULL,
            cpu_percent REAL NOT NULL,
            mem_percent REAL NOT NULL,
            rss_bytes INTEGER NOT NULL,
            FOREIGN KEY (snapshot_id) REFERENCES snapshots(id)
        );

        CREATE TABLE IF NOT EXISTS connection_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mac_address TEXT NOT NULL,
            ip_address TEXT NOT NULL,
            hostname TEXT,
            interface TEXT NOT NULL,
            first_seen REAL NOT NULL,
            last_seen REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_connection_log_mac ON connection_log(mac_address);
        CREATE INDEX IF NOT EXISTS idx_connection_log_last_seen ON connection_log(last_seen);
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }

        // Migration: add health_score column if not present (ignore error if exists)
        sqlite3_exec(db, "ALTER TABLE snapshots ADD COLUMN health_score INTEGER DEFAULT NULL", nil, nil, nil)
    }

    // MARK: - Write

    public func saveSnapshot(_ snapshot: HealthSnapshot, healthScore: Int? = nil) throws {
        let sql = """
        INSERT INTO snapshots (
            timestamp, cpu_user, cpu_system, cpu_idle,
            load_1m, load_5m, load_15m,
            mem_total, mem_used, mem_wired, mem_compressed,
            swap_used, swap_total,
            disk_total, disk_used, disk_available,
            battery_percent, battery_charging, thermal_state,
            health_score
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let s = snapshot
        sqlite3_bind_double(stmt, 1, s.timestamp.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 2, s.cpu.userPercent)
        sqlite3_bind_double(stmt, 3, s.cpu.systemPercent)
        sqlite3_bind_double(stmt, 4, s.cpu.idlePercent)
        sqlite3_bind_double(stmt, 5, s.cpu.loadAverage.0)
        sqlite3_bind_double(stmt, 6, s.cpu.loadAverage.1)
        sqlite3_bind_double(stmt, 7, s.cpu.loadAverage.2)
        sqlite3_bind_int64(stmt, 8, Int64(s.memory.totalBytes))
        sqlite3_bind_int64(stmt, 9, Int64(s.memory.usedBytes))
        sqlite3_bind_int64(stmt, 10, Int64(s.memory.wiredBytes))
        sqlite3_bind_int64(stmt, 11, Int64(s.memory.compressedBytes))
        sqlite3_bind_int64(stmt, 12, Int64(s.memory.swapUsedBytes))
        sqlite3_bind_int64(stmt, 13, Int64(s.memory.swapTotalBytes))
        sqlite3_bind_int64(stmt, 14, Int64(s.disk.totalBytes))
        sqlite3_bind_int64(stmt, 15, Int64(s.disk.usedBytes))
        sqlite3_bind_int64(stmt, 16, Int64(s.disk.availableBytes))
        sqlite3_bind_int(stmt, 17, Int32(s.battery.percentage))
        sqlite3_bind_int(stmt, 18, s.battery.isCharging ? 1 : 0)
        sqlite3_bind_text(stmt, 19, (s.thermal.state.rawValue as NSString).utf8String, -1, nil)
        if let score = healthScore {
            sqlite3_bind_int(stmt, 20, Int32(score))
        } else {
            sqlite3_bind_null(stmt, 20)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }

        let snapshotId = sqlite3_last_insert_rowid(db)

        for proc in s.topProcesses.prefix(10) {
            try saveProcess(snapshotId: snapshotId, process: proc)
        }
    }

    private func saveProcess(snapshotId: Int64, process: HKProcessInfo) throws {
        let sql = "INSERT INTO top_processes (snapshot_id, pid, name, cpu_percent, mem_percent, rss_bytes) VALUES (?,?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, snapshotId)
        sqlite3_bind_int(stmt, 2, process.pid)
        sqlite3_bind_text(stmt, 3, (process.name as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, process.cpuPercent)
        sqlite3_bind_double(stmt, 5, process.memPercent)
        sqlite3_bind_int64(stmt, 6, Int64(process.rssBytes))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Connection Log

    public struct DeviceRecord {
        public let macAddress: String
        public let ipAddress: String
        public let hostname: String?
        public let interface: String
        public let firstSeen: Date
        public let lastSeen: Date
    }

    /// Upsert a device sighting: update last_seen if MAC exists, otherwise insert.
    public func logDeviceSighting(macAddress: String, ipAddress: String,
                                   hostname: String?, interface: String) throws {
        let now = Date().timeIntervalSince1970

        let selectSQL = "SELECT id FROM connection_log WHERE mac_address = ?"
        var selectStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(selectStmt) }
        sqlite3_bind_text(selectStmt, 1, (macAddress as NSString).utf8String, -1, nil)

        if sqlite3_step(selectStmt) == SQLITE_ROW {
            let updateSQL = """
            UPDATE connection_log SET last_seen = ?, ip_address = ?,
                   hostname = COALESCE(?, hostname), interface = ?
            WHERE mac_address = ?
            """
            var updateStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK else {
                throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(updateStmt) }
            sqlite3_bind_double(updateStmt, 1, now)
            sqlite3_bind_text(updateStmt, 2, (ipAddress as NSString).utf8String, -1, nil)
            if let hostname = hostname {
                sqlite3_bind_text(updateStmt, 3, (hostname as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(updateStmt, 3)
            }
            sqlite3_bind_text(updateStmt, 4, (interface as NSString).utf8String, -1, nil)
            sqlite3_bind_text(updateStmt, 5, (macAddress as NSString).utf8String, -1, nil)
            guard sqlite3_step(updateStmt) == SQLITE_DONE else {
                throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
            }
        } else {
            let insertSQL = """
            INSERT INTO connection_log (mac_address, ip_address, hostname, interface, first_seen, last_seen)
            VALUES (?, ?, ?, ?, ?, ?)
            """
            var insertStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else {
                throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(insertStmt) }
            sqlite3_bind_text(insertStmt, 1, (macAddress as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStmt, 2, (ipAddress as NSString).utf8String, -1, nil)
            if let hostname = hostname {
                sqlite3_bind_text(insertStmt, 3, (hostname as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(insertStmt, 3)
            }
            sqlite3_bind_text(insertStmt, 4, (interface as NSString).utf8String, -1, nil)
            sqlite3_bind_double(insertStmt, 5, now)
            sqlite3_bind_double(insertStmt, 6, now)
            guard sqlite3_step(insertStmt) == SQLITE_DONE else {
                throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    /// Get device history ordered by last_seen descending.
    public func getDeviceHistory(limit: Int = 50) throws -> [DeviceRecord] {
        let sql = "SELECT mac_address, ip_address, hostname, interface, first_seen, last_seen FROM connection_log ORDER BY last_seen DESC LIMIT ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var results: [DeviceRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let record = DeviceRecord(
                macAddress: String(cString: sqlite3_column_text(stmt, 0)),
                ipAddress: String(cString: sqlite3_column_text(stmt, 1)),
                hostname: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                interface: String(cString: sqlite3_column_text(stmt, 3)),
                firstSeen: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
                lastSeen: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
            )
            results.append(record)
        }
        return results
    }

    // MARK: - Read

    public struct HistoryPoint {
        public let timestamp: Date
        public let cpuUsage: Double
        public let memoryUsage: Double
        public let swapUsed: UInt64
        public let diskUsage: Double
        public let batteryPercent: Int
        public let thermalState: String
        public let load1m: Double
        public let healthScore: Int?
    }

    /// Get history points for the last N hours
    public func getHistory(hours: Int = 24, limit: Int = 100) throws -> [HistoryPoint] {
        let since = Date().addingTimeInterval(-Double(hours * 3600)).timeIntervalSince1970
        let sql = """
        SELECT timestamp, cpu_user + cpu_system,
               CAST(mem_used AS REAL) / CAST(mem_total AS REAL) * 100,
               swap_used,
               CAST(disk_used AS REAL) / CAST(disk_total AS REAL) * 100,
               battery_percent, thermal_state, load_1m, health_score
        FROM snapshots
        WHERE timestamp > ?
        ORDER BY timestamp ASC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, since)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [HistoryPoint] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let scoreVal = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 8))
            let point = HistoryPoint(
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                cpuUsage: sqlite3_column_double(stmt, 1),
                memoryUsage: sqlite3_column_double(stmt, 2),
                swapUsed: UInt64(sqlite3_column_int64(stmt, 3)),
                diskUsage: sqlite3_column_double(stmt, 4),
                batteryPercent: Int(sqlite3_column_int(stmt, 5)),
                thermalState: String(cString: sqlite3_column_text(stmt, 6)),
                load1m: sqlite3_column_double(stmt, 7),
                healthScore: scoreVal
            )
            results.append(point)
        }

        return results
    }

    /// Get total snapshot count
    public func getSnapshotCount() throws -> Int {
        let sql = "SELECT COUNT(*) FROM snapshots"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_step(stmt)
        return Int(sqlite3_column_int(stmt, 0))
    }

    /// Get time range of stored data
    public func getTimeRange() throws -> (first: Date, last: Date)? {
        let sql = "SELECT MIN(timestamp), MAX(timestamp) FROM snapshots"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let first = sqlite3_column_double(stmt, 0)
        let last = sqlite3_column_double(stmt, 1)
        guard first > 0 else { return nil }
        return (Date(timeIntervalSince1970: first), Date(timeIntervalSince1970: last))
    }

    /// Prune old data (keep last N days)
    public func prune(keepDays: Int = 30) throws -> Int {
        let cutoff = Date().addingTimeInterval(-Double(keepDays * 86400)).timeIntervalSince1970
        let deleteProcs = "DELETE FROM top_processes WHERE snapshot_id IN (SELECT id FROM snapshots WHERE timestamp < ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteProcs, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        sqlite3_bind_double(stmt, 1, cutoff)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)

        let deleteSnaps = "DELETE FROM snapshots WHERE timestamp < ?"
        guard sqlite3_prepare_v2(db, deleteSnaps, -1, &stmt, nil) == SQLITE_OK else {
            throw HKStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        sqlite3_bind_double(stmt, 1, cutoff)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return Int(sqlite3_changes(db))
    }
}

public enum HKStoreError: Error, LocalizedError {
    case cannotOpen(String)
    case query(String)

    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let msg): return "Cannot open database: \(msg)"
        case .query(let msg): return "Database error: \(msg)"
        }
    }
}
