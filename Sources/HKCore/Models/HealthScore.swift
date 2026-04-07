import Foundation

public struct ScoreDeduction: Sendable, Codable {
    public let category: String
    public let label: String
    public let explanation: String
    public let penalty: Int

    public init(category: String, label: String, explanation: String, penalty: Int) {
        self.category = category
        self.label = label
        self.explanation = explanation
        self.penalty = penalty
    }
}

public struct HealthScore: Sendable, Codable {
    public let score: Int
    public let deductions: [ScoreDeduction]
    public let timestamp: Date

    public var rating: String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90:  return "Good"
        case 50..<75:  return "Fair"
        case 25..<50:  return "Poor"
        default:       return "Critical"
        }
    }

    public var ratingColor: String {
        switch score {
        case 75...100: return "green"
        case 50..<75:  return "orange"
        default:       return "red"
        }
    }

    public init(score: Int, deductions: [ScoreDeduction], timestamp: Date = Date()) {
        self.score = max(0, min(100, score))
        self.deductions = deductions
        self.timestamp = timestamp
    }
}

public enum HealthScoreCalculator {

    public static func calculate(
        cpu: CPUInfo,
        memory: MemoryInfo,
        disk: DiskInfo,
        thermal: ThermalInfo,
        battery: BatteryInfo,
        topProcesses: [HKProcessInfo]
    ) -> HealthScore {
        var deductions: [ScoreDeduction] = []

        // CPU penalty (max -15): based on load/core ratio
        let loadRatio = cpu.loadAverage.0 / Double(max(cpu.coreCount, 1))
        if loadRatio > 0.7 {
            let rawPenalty = Int(((loadRatio - 0.7) / 1.3) * 15.0)
            let penalty = min(max(rawPenalty, 1), 15)
            deductions.append(ScoreDeduction(
                category: "CPU",
                label: "High CPU load",
                explanation: String(format: "Load avg %.1f on %d cores (ratio %.1f)",
                                    cpu.loadAverage.0, cpu.coreCount, loadRatio),
                penalty: penalty
            ))
        }

        // Memory penalty (max -15): scaled 60%-95%
        let memPct = memory.usagePercent
        if memPct > 60 {
            let rawPenalty = Int(((memPct - 60.0) / 35.0) * 15.0)
            let penalty = min(max(rawPenalty, 1), 15)
            deductions.append(ScoreDeduction(
                category: "Memory",
                label: "High memory usage",
                explanation: String(format: "%.0f%% used (%@ of %@)",
                                    memPct,
                                    ByteFormatter.format(memory.usedBytes),
                                    ByteFormatter.format(memory.totalBytes)),
                penalty: penalty
            ))
        }

        // Swap penalty (extra, max -5)
        let swapGB = Double(memory.swapUsedBytes) / (1024 * 1024 * 1024)
        if swapGB > 2.0 {
            let penalty = min(Int(swapGB - 1.0), 5)
            deductions.append(ScoreDeduction(
                category: "Memory",
                label: "Heavy swap usage",
                explanation: String(format: "%.1f GB swap in use", swapGB),
                penalty: penalty
            ))
        }

        // Disk penalty (max -15): scaled 70%-95%
        let diskPct = disk.usagePercent
        if diskPct > 70 {
            let rawPenalty = Int(((diskPct - 70.0) / 25.0) * 15.0)
            let penalty = min(max(rawPenalty, 1), 15)
            deductions.append(ScoreDeduction(
                category: "Disk",
                label: "Low disk space",
                explanation: String(format: "%.0f%% used (%@ available)",
                                    diskPct, ByteFormatter.format(disk.availableBytes)),
                penalty: penalty
            ))
        }

        // Thermal penalty (max -15)
        switch thermal.state {
        case .fair:
            deductions.append(ScoreDeduction(
                category: "Thermal",
                label: "Warm (Fair)",
                explanation: "System is moderately warm, may throttle",
                penalty: 5
            ))
        case .serious:
            deductions.append(ScoreDeduction(
                category: "Thermal",
                label: "Hot (Serious)",
                explanation: "System is hot, performance throttled",
                penalty: 12
            ))
        case .critical:
            deductions.append(ScoreDeduction(
                category: "Thermal",
                label: "Thermal critical",
                explanation: "System critically hot, heavy throttling",
                penalty: 15
            ))
        default:
            break
        }

        // Battery penalty (max -10)
        if battery.available {
            var batteryPenalty = 0
            var explanations: [String] = []

            if battery.cycleCount > 500 {
                let cyclePenalty = min(Int(Double(battery.cycleCount - 500) / 100.0), 5)
                if cyclePenalty > 0 {
                    batteryPenalty += cyclePenalty
                    explanations.append("\(battery.cycleCount) cycles (of ~1000 expected)")
                }
            }

            if let pctRange = battery.health.range(of: "\\d+", options: .regularExpression) {
                let healthPct = Int(battery.health[pctRange]) ?? 100
                if healthPct < 90 {
                    let healthPenalty = min((90 - healthPct) / 5, 5)
                    if healthPenalty > 0 {
                        batteryPenalty += healthPenalty
                        explanations.append("battery health at \(healthPct)%")
                    }
                }
            }

            if batteryPenalty > 0 {
                deductions.append(ScoreDeduction(
                    category: "Battery",
                    label: "Battery wear",
                    explanation: explanations.joined(separator: "; "),
                    penalty: min(batteryPenalty, 10)
                ))
            }
        }

        // Process outlier penalty (max -10)
        var processIssues: [String] = []
        for proc in topProcesses.prefix(5) where proc.cpuPercent > 50 {
            processIssues.append("\(proc.shortName) at \(Int(proc.cpuPercent))% CPU")
        }
        for proc in topProcesses.prefix(5) where proc.rssBytes > 3 * 1024 * 1024 * 1024 {
            processIssues.append("\(proc.shortName) using \(ByteFormatter.format(proc.rssBytes)) RAM")
        }

        if !processIssues.isEmpty {
            let penalty = min(processIssues.count * 3, 10)
            deductions.append(ScoreDeduction(
                category: "Processes",
                label: "Resource-heavy processes",
                explanation: processIssues.joined(separator: "; "),
                penalty: penalty
            ))
        }

        let totalPenalty = deductions.reduce(0) { $0 + $1.penalty }
        return HealthScore(score: 100 - totalPenalty, deductions: deductions)
    }
}
