import Foundation

/// Aggregates process data from the top_processes table to build energy profiles per app.
public enum AppProfiler {
    public struct AppProfile: Sendable, Codable {
        public let name: String
        public let cpuHours: Double
        public let avgCpuPercent: Double
        public let peakCpuPercent: Double
        public let avgMemoryMB: Double
        public let peakMemoryMB: Double
        public let sightings: Int
        public let firstSeen: Date
        public let lastSeen: Date
        public let grade: String
    }

    /// Get app profiles for the last N days, sorted by cpuHours descending, top 20.
    public static func getProfiles(store: HealthStore, days: Int = 7) throws -> [AppProfile] {
        let records = try store.getProcessHistory(days: days)
        guard !records.isEmpty else { return [] }

        // Group records by short app name (extract from bundle paths)
        var grouped: [String: [HealthStore.ProcessRecord]] = [:]
        for record in records {
            let short = shortAppName(record.name)
            grouped[short, default: []].append(record)
        }

        // Collect all unique snapshot timestamps to estimate interval
        let allTimestamps = Set(records.map { $0.snapshotTimestamp.timeIntervalSince1970 })
            .sorted()
        let intervalSeconds = estimateSnapshotInterval(from: allTimestamps)

        var profiles: [AppProfile] = []

        for (name, appRecords) in grouped {
            let sightings = appRecords.count

            // CPU-hours: each sighting represents one snapshot interval
            // cpuHours = sum of (cpu_percent / 100.0 * interval_in_hours)
            let intervalHours = intervalSeconds / 3600.0
            let totalCpuHours = appRecords.reduce(0.0) { sum, r in
                sum + (r.cpuPercent / 100.0 * intervalHours)
            }

            let avgCpu = appRecords.map(\.cpuPercent).reduce(0, +) / Double(sightings)
            let peakCpu = appRecords.map(\.cpuPercent).max() ?? 0

            let memoryMBValues = appRecords.map { Double($0.rssBytes) / (1024 * 1024) }
            let avgMemMB = memoryMBValues.reduce(0, +) / Double(sightings)
            let peakMemMB = memoryMBValues.max() ?? 0

            let timestamps = appRecords.map(\.snapshotTimestamp)
            let firstSeen = timestamps.min() ?? Date()
            let lastSeen = timestamps.max() ?? Date()

            let grade = calculateGrade(
                cpuHours: totalCpuHours,
                sightings: sightings,
                intervalSeconds: intervalSeconds
            )

            profiles.append(AppProfile(
                name: name,
                cpuHours: totalCpuHours,
                avgCpuPercent: avgCpu,
                peakCpuPercent: peakCpu,
                avgMemoryMB: avgMemMB,
                peakMemoryMB: peakMemMB,
                sightings: sightings,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                grade: grade
            ))
        }

        // Sort by cpuHours descending and return top 20
        profiles.sort { $0.cpuHours > $1.cpuHours }
        return Array(profiles.prefix(20))
    }

    /// Grade calculation based on average CPU usage across sightings.
    /// Uses cpuHours relative to the number of sightings and interval
    /// to determine how resource-intensive the app is on average.
    static func calculateGrade(cpuHours: Double, sightings: Int, intervalSeconds: Double) -> String {
        guard sightings > 0, intervalSeconds > 0 else { return "A" }

        // Average CPU fraction per sighting:
        // cpuHours = sum(cpu% / 100 * intervalHrs) over N sightings
        // avgCpuFraction = cpuHours / (sightings * intervalHrs)
        let intervalHours = intervalSeconds / 3600.0
        let avgCpuFraction = cpuHours / (Double(sightings) * intervalHours)
        // Convert back to percent
        let avgCpuPercent = avgCpuFraction * 100.0

        switch avgCpuPercent {
        case ..<3:
            return "A"   // Very efficient
        case 3..<10:
            return "B"   // Efficient
        case 10..<25:
            return "C"   // Moderate
        case 25..<50:
            return "D"   // Heavy
        default:
            return "F"   // Resource hog
        }
    }

    /// Extract a user-friendly short name from a full process path.
    /// "/Applications/Arc.app/Contents/MacOS/Arc" → "Arc"
    /// "/System/Library/.../WindowServer" → "WindowServer"
    private static func shortAppName(_ fullName: String) -> String {
        // Check for .app bundle path
        if let range = fullName.range(of: ".app/") {
            let appPart = fullName[..<range.lowerBound]
            if let lastSlash = appPart.lastIndex(of: "/") {
                return String(appPart[appPart.index(after: lastSlash)...])
            }
            return String(appPart)
        }
        // Fall back to last path component
        if let lastSlash = fullName.lastIndex(of: "/") {
            return String(fullName[fullName.index(after: lastSlash)...])
        }
        return fullName
    }

    /// Estimate the typical interval between snapshots from sorted timestamps.
    private static func estimateSnapshotInterval(from sortedTimestamps: [Double]) -> Double {
        guard sortedTimestamps.count >= 2 else {
            // Default to 5 minutes if we only have one snapshot
            return 300
        }

        // Calculate median interval between consecutive timestamps
        var intervals: [Double] = []
        for i in 1..<sortedTimestamps.count {
            let diff = sortedTimestamps[i] - sortedTimestamps[i - 1]
            if diff > 0 && diff < 86400 { // Ignore gaps > 24h
                intervals.append(diff)
            }
        }

        guard !intervals.isEmpty else { return 300 }

        intervals.sort()
        return intervals[intervals.count / 2] // Median
    }
}