import Foundation

/// Time-travel comparison between current system state and a historical snapshot.
public enum TimeTravelDiff {
    public struct SystemDiff: Sendable, Codable {
        public let currentTimestamp: Date
        public let comparisonTimestamp: Date
        public let timeSpan: String
        public let changes: [MetricChange]
        public let newProcesses: [String]
        public let goneProcesses: [String]
        public let scoreChange: Int?
    }

    public struct MetricChange: Sendable, Codable {
        public let metric: String
        public let oldValue: Double
        public let newValue: Double
        public let unit: String
        public let changePercent: Double
        public let significance: Significance
    }

    public enum Significance: String, Sendable, Codable {
        case major, minor, negligible
    }

    /// Compare current state to a snapshot from `daysAgo` days in the past.
    public static func compare(store: HealthStore, daysAgo: Int) throws -> SystemDiff? {
        let targetDate = Date().addingTimeInterval(-Double(daysAgo) * 86400)

        // Get historical snapshot
        guard let old = try store.getSnapshotNear(date: targetDate) else {
            return nil
        }

        // Get most recent snapshot (now)
        guard let current = try store.getSnapshotNear(date: Date()) else {
            return nil
        }

        // Ensure the old snapshot is actually from roughly the right time period
        let actualDaysAgo = Date().timeIntervalSince(old.snapshot.timestamp) / 86400.0
        guard actualDaysAgo > Double(daysAgo) * 0.3 else {
            // The "old" snapshot is too recent, probably same as current
            return nil
        }

        let timeSpanStr = formatTimeSpan(daysAgo: daysAgo)

        // Build metric changes
        var changes: [MetricChange] = []

        // Health Score
        if let oldScore = old.snapshot.healthScore, let newScore = current.snapshot.healthScore {
            changes.append(buildChange(
                metric: "Health Score", oldVal: Double(oldScore), newVal: Double(newScore), unit: "pts",
                majorThreshold: 10, minorThreshold: 3
            ))
        }

        // CPU Usage
        changes.append(buildChange(
            metric: "CPU Usage", oldVal: old.snapshot.cpuUsage, newVal: current.snapshot.cpuUsage, unit: "%",
            majorThreshold: 20, minorThreshold: 5
        ))

        // Memory Usage
        changes.append(buildChange(
            metric: "Memory", oldVal: old.snapshot.memoryUsage, newVal: current.snapshot.memoryUsage, unit: "%",
            majorThreshold: 15, minorThreshold: 5
        ))

        // Disk Usage
        changes.append(buildChange(
            metric: "Disk", oldVal: old.snapshot.diskUsage, newVal: current.snapshot.diskUsage, unit: "%",
            majorThreshold: 10, minorThreshold: 3
        ))

        // Swap Used (in GB)
        let oldSwapGB = Double(old.snapshot.swapUsed) / (1024 * 1024 * 1024)
        let newSwapGB = Double(current.snapshot.swapUsed) / (1024 * 1024 * 1024)
        changes.append(buildChange(
            metric: "Swap", oldVal: oldSwapGB, newVal: newSwapGB, unit: "GB",
            majorThreshold: 50, minorThreshold: 20
        ))

        // Battery
        changes.append(buildChange(
            metric: "Battery", oldVal: Double(old.snapshot.batteryPercent),
            newVal: Double(current.snapshot.batteryPercent), unit: "%",
            majorThreshold: 20, minorThreshold: 5
        ))

        // Load Average
        changes.append(buildChange(
            metric: "Load 1m", oldVal: old.snapshot.load1m, newVal: current.snapshot.load1m, unit: "",
            majorThreshold: 50, minorThreshold: 20
        ))

        // Process diff
        let oldSet = Set(old.processes)
        let newSet = Set(current.processes)
        let newProcesses = Array(newSet.subtracting(oldSet)).sorted()
        let goneProcesses = Array(oldSet.subtracting(newSet)).sorted()

        // Score delta
        let scoreDelta: Int?
        if let os = old.snapshot.healthScore, let ns = current.snapshot.healthScore {
            scoreDelta = ns - os
        } else {
            scoreDelta = nil
        }

        return SystemDiff(
            currentTimestamp: current.snapshot.timestamp,
            comparisonTimestamp: old.snapshot.timestamp,
            timeSpan: timeSpanStr,
            changes: changes,
            newProcesses: newProcesses,
            goneProcesses: goneProcesses,
            scoreChange: scoreDelta
        )
    }

    // MARK: - Helpers

    private static func buildChange(metric: String, oldVal: Double, newVal: Double,
                                     unit: String, majorThreshold: Double,
                                     minorThreshold: Double) -> MetricChange {
        let changePct: Double
        if oldVal != 0 {
            changePct = ((newVal - oldVal) / abs(oldVal)) * 100.0
        } else if newVal != 0 {
            changePct = 100.0
        } else {
            changePct = 0
        }

        let sig: Significance
        if abs(changePct) >= majorThreshold {
            sig = .major
        } else if abs(changePct) >= minorThreshold {
            sig = .minor
        } else {
            sig = .negligible
        }

        return MetricChange(
            metric: metric, oldValue: oldVal, newValue: newVal,
            unit: unit, changePercent: changePct, significance: sig
        )
    }

    private static func formatTimeSpan(daysAgo: Int) -> String {
        switch daysAgo {
        case 1: return "yesterday"
        case 7: return "7 days ago"
        case 14: return "2 weeks ago"
        case 30: return "30 days ago"
        default: return "\(daysAgo) days ago"
        }
    }
}