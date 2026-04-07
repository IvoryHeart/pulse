import Foundation
import SQLite3

extension HealthStore {

    public struct DailySummary: Sendable, Codable {
        public let date: String
        public let snapshotCount: Int
        public let avgCpuUsage: Double
        public let maxCpuUsage: Double
        public let avgMemUsage: Double
        public let maxMemUsage: Double
        public let avgDiskUsage: Double
        public let maxSwapUsed: Int64
        public let avgHealthScore: Double?
        public let minHealthScore: Int?
        public let maxHealthScore: Int?
        public let worstThermalState: String
        public let avgBatteryPercent: Double?
    }

    public struct DatabaseStats: Sendable, Codable {
        public let fileSizeBytes: Int64
        public let snapshotCount: Int
        public let processRecordCount: Int
        public let deviceRecordCount: Int
        public let dailySummaryCount: Int
        public let oldestSnapshot: Date?
        public let newestSnapshot: Date?
        public let archivedDaysCount: Int
    }

    // MARK: - Table Creation

    public func createArchiveTables() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS daily_summaries (
                date TEXT PRIMARY KEY,
                snapshot_count INTEGER NOT NULL,
                avg_cpu_usage REAL,
                max_cpu_usage REAL,
                avg_mem_usage REAL,
                max_mem_usage REAL,
                avg_disk_usage REAL,
                max_swap_used INTEGER,
                avg_health_score REAL,
                min_health_score INTEGER,
                max_health_score INTEGER,
                worst_thermal_state TEXT,
                avg_battery_percent REAL
            );
            """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Archive

    public func archiveOldData(olderThanDays: Int = 14) throws -> (archivedDays: Int, deletedSnapshots: Int, freedBytes: Int64) {
        try createArchiveTables()
        let sizeBefore = try getDatabaseSize()

        let cutoff = Date().addingTimeInterval(-Double(olderThanDays * 86400)).timeIntervalSince1970

        // Find distinct dates with old snapshots
        let dateSQL = "SELECT DISTINCT date(timestamp, 'unixepoch', 'localtime') FROM snapshots WHERE timestamp < ?"
        var dateStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, dateSQL, -1, &dateStmt, nil) == SQLITE_OK else {
            throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(dateStmt) }
        sqlite3_bind_double(dateStmt, 1, cutoff)

        var dates: [String] = []
        while sqlite3_step(dateStmt) == SQLITE_ROW {
            dates.append(String(cString: sqlite3_column_text(dateStmt, 0)))
        }

        guard !dates.isEmpty else { return (0, 0, 0) }

        var totalDeleted = 0

        for dateStr in dates {
            // Compute daily summary
            let aggSQL = """
                SELECT COUNT(*),
                       AVG(cpu_user + cpu_system), MAX(cpu_user + cpu_system),
                       AVG(CAST(mem_used AS REAL) / CAST(mem_total AS REAL) * 100),
                       MAX(CAST(mem_used AS REAL) / CAST(mem_total AS REAL) * 100),
                       AVG(CAST(disk_used AS REAL) / CAST(disk_total AS REAL) * 100),
                       MAX(swap_used),
                       AVG(health_score), MIN(health_score), MAX(health_score),
                       AVG(battery_percent)
                FROM snapshots
                WHERE date(timestamp, 'unixepoch', 'localtime') = ?
                """
            var aggStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, aggSQL, -1, &aggStmt, nil) == SQLITE_OK else {
                throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(aggStmt) }
            sqlite3_bind_text(aggStmt, 1, (dateStr as NSString).utf8String, -1, nil)

            guard sqlite3_step(aggStmt) == SQLITE_ROW else { continue }

            let count = Int(sqlite3_column_int(aggStmt, 0))
            let avgCpu = sqlite3_column_double(aggStmt, 1)
            let maxCpu = sqlite3_column_double(aggStmt, 2)
            let avgMem = sqlite3_column_double(aggStmt, 3)
            let maxMem = sqlite3_column_double(aggStmt, 4)
            let avgDisk = sqlite3_column_double(aggStmt, 5)
            let maxSwap = sqlite3_column_int64(aggStmt, 6)
            let avgScore: Double? = sqlite3_column_type(aggStmt, 7) == SQLITE_NULL ? nil : sqlite3_column_double(aggStmt, 7)
            let minScore: Int? = sqlite3_column_type(aggStmt, 8) == SQLITE_NULL ? nil : Int(sqlite3_column_int(aggStmt, 8))
            let maxScore: Int? = sqlite3_column_type(aggStmt, 9) == SQLITE_NULL ? nil : Int(sqlite3_column_int(aggStmt, 9))
            let avgBattery: Double? = sqlite3_column_type(aggStmt, 10) == SQLITE_NULL ? nil : sqlite3_column_double(aggStmt, 10)

            // Get worst thermal state for that day
            let thermalSQL = "SELECT DISTINCT thermal_state FROM snapshots WHERE date(timestamp, 'unixepoch', 'localtime') = ?"
            var thermalStmt: OpaquePointer?
            var worstThermal = "nominal"
            if sqlite3_prepare_v2(db, thermalSQL, -1, &thermalStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(thermalStmt, 1, (dateStr as NSString).utf8String, -1, nil)
                let thermalRank = ["nominal": 0, "fair": 1, "serious": 2, "critical": 3]
                while sqlite3_step(thermalStmt) == SQLITE_ROW {
                    let state = String(cString: sqlite3_column_text(thermalStmt, 0))
                    if (thermalRank[state] ?? 0) > (thermalRank[worstThermal] ?? 0) {
                        worstThermal = state
                    }
                }
                sqlite3_finalize(thermalStmt)
            }

            // Insert/replace daily summary
            let insertSQL = """
                INSERT OR REPLACE INTO daily_summaries
                (date, snapshot_count, avg_cpu_usage, max_cpu_usage, avg_mem_usage, max_mem_usage,
                 avg_disk_usage, max_swap_used, avg_health_score, min_health_score, max_health_score,
                 worst_thermal_state, avg_battery_percent)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            var insertStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else {
                throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
            }
            sqlite3_bind_text(insertStmt, 1, (dateStr as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStmt, 2, Int32(count))
            sqlite3_bind_double(insertStmt, 3, avgCpu)
            sqlite3_bind_double(insertStmt, 4, maxCpu)
            sqlite3_bind_double(insertStmt, 5, avgMem)
            sqlite3_bind_double(insertStmt, 6, maxMem)
            sqlite3_bind_double(insertStmt, 7, avgDisk)
            sqlite3_bind_int64(insertStmt, 8, maxSwap)
            if let s = avgScore { sqlite3_bind_double(insertStmt, 9, s) } else { sqlite3_bind_null(insertStmt, 9) }
            if let s = minScore { sqlite3_bind_int(insertStmt, 10, Int32(s)) } else { sqlite3_bind_null(insertStmt, 10) }
            if let s = maxScore { sqlite3_bind_int(insertStmt, 11, Int32(s)) } else { sqlite3_bind_null(insertStmt, 11) }
            sqlite3_bind_text(insertStmt, 12, (worstThermal as NSString).utf8String, -1, nil)
            if let b = avgBattery { sqlite3_bind_double(insertStmt, 13, b) } else { sqlite3_bind_null(insertStmt, 13) }
            sqlite3_step(insertStmt)
            sqlite3_finalize(insertStmt)

            // Delete original snapshots for that date
            let delProcsSQL = "DELETE FROM top_processes WHERE snapshot_id IN (SELECT id FROM snapshots WHERE date(timestamp, 'unixepoch', 'localtime') = ?)"
            var delProcsStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, delProcsSQL, -1, &delProcsStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(delProcsStmt, 1, (dateStr as NSString).utf8String, -1, nil)
                sqlite3_step(delProcsStmt)
                sqlite3_finalize(delProcsStmt)
            }

            let delSnapsSQL = "DELETE FROM snapshots WHERE date(timestamp, 'unixepoch', 'localtime') = ?"
            var delSnapsStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, delSnapsSQL, -1, &delSnapsStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(delSnapsStmt, 1, (dateStr as NSString).utf8String, -1, nil)
                sqlite3_step(delSnapsStmt)
                totalDeleted += Int(sqlite3_changes(db))
                sqlite3_finalize(delSnapsStmt)
            }
        }

        let sizeAfter = try getDatabaseSize()
        return (dates.count, totalDeleted, max(0, sizeBefore - sizeAfter))
    }

    // MARK: - Daily Summaries

    public func getDailySummaries(days: Int = 90) throws -> [DailySummary] {
        try createArchiveTables()
        let sql = "SELECT * FROM daily_summaries ORDER BY date DESC LIMIT ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(days))

        var results: [DailySummary] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(DailySummary(
                date: String(cString: sqlite3_column_text(stmt, 0)),
                snapshotCount: Int(sqlite3_column_int(stmt, 1)),
                avgCpuUsage: sqlite3_column_double(stmt, 2),
                maxCpuUsage: sqlite3_column_double(stmt, 3),
                avgMemUsage: sqlite3_column_double(stmt, 4),
                maxMemUsage: sqlite3_column_double(stmt, 5),
                avgDiskUsage: sqlite3_column_double(stmt, 6),
                maxSwapUsed: sqlite3_column_int64(stmt, 7),
                avgHealthScore: sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 8),
                minHealthScore: sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 9)),
                maxHealthScore: sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 10)),
                worstThermalState: String(cString: sqlite3_column_text(stmt, 11)),
                avgBatteryPercent: sqlite3_column_type(stmt, 12) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 12)
            ))
        }
        return results
    }

    // MARK: - Vacuum & Stats

    public func vacuum() throws {
        guard sqlite3_exec(db, "VACUUM", nil, nil, nil) == SQLITE_OK else {
            throw PulseStoreError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    public func getDatabaseSize() throws -> Int64 {
        let path = Self.dbPath
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        return (attrs[.size] as? Int64) ?? 0
    }

    public func getDatabaseStats() throws -> DatabaseStats {
        try createArchiveTables()
        let snapCount = try getSnapshotCount()
        let fileSize = try getDatabaseSize()

        // Process record count
        var procCount = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM top_processes", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { procCount = Int(sqlite3_column_int(stmt, 0)) }
            sqlite3_finalize(stmt)
        }

        // Device record count
        var deviceCount = 0
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM connection_log", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { deviceCount = Int(sqlite3_column_int(stmt, 0)) }
            sqlite3_finalize(stmt)
        }

        // Daily summary count
        var summaryCount = 0
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM daily_summaries", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { summaryCount = Int(sqlite3_column_int(stmt, 0)) }
            sqlite3_finalize(stmt)
        }

        let timeRange = try getTimeRange()

        return DatabaseStats(
            fileSizeBytes: fileSize,
            snapshotCount: snapCount,
            processRecordCount: procCount,
            deviceRecordCount: deviceCount,
            dailySummaryCount: summaryCount,
            oldestSnapshot: timeRange?.first,
            newestSnapshot: timeRange?.last,
            archivedDaysCount: summaryCount
        )
    }

    // MARK: - Auto Maintenance

    public func autoMaintenance(archiveAfterDays: Int = 14, maxSizeMB: Int = 50) throws -> String {
        var messages: [String] = []
        let sizeBefore = try getDatabaseSize()
        let sizeMB = Double(sizeBefore) / 1_000_000.0

        let archiveDays = sizeMB > Double(maxSizeMB) ? 7 : archiveAfterDays
        let result = try archiveOldData(olderThanDays: archiveDays)

        if result.archivedDays > 0 {
            messages.append("Archived \(result.archivedDays) days (\(result.deletedSnapshots) snapshots)")
        }

        let sizeAfter = try getDatabaseSize()
        let afterMB = Double(sizeAfter) / 1_000_000.0

        if afterMB > Double(maxSizeMB) || result.deletedSnapshots > 100 {
            try vacuum()
            let finalSize = try getDatabaseSize()
            let finalMB = Double(finalSize) / 1_000_000.0
            messages.append(String(format: "Vacuumed: %.1f MB → %.1f MB", afterMB, finalMB))
        }

        if messages.isEmpty {
            return "Database is healthy. No maintenance needed."
        }
        return messages.joined(separator: ". ") + "."
    }

    // MARK: - Export

    public func exportData(days: Int = 7) throws -> String {
        let history = try getHistory(hours: days * 24, limit: 10000)

        struct ExportPoint: Codable {
            let timestamp: String
            let cpuUsage: Double
            let memoryUsage: Double
            let diskUsage: Double
            let swapUsedBytes: UInt64
            let batteryPercent: Int
            let thermalState: String
            let load1m: Double
            let healthScore: Int?
        }

        let formatter = ISO8601DateFormatter()
        let points = history.map { p in
            ExportPoint(
                timestamp: formatter.string(from: p.timestamp),
                cpuUsage: p.cpuUsage,
                memoryUsage: p.memoryUsage,
                diskUsage: p.diskUsage,
                swapUsedBytes: p.swapUsed,
                batteryPercent: p.batteryPercent,
                thermalState: p.thermalState,
                load1m: p.load1m,
                healthScore: p.healthScore
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(points)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
