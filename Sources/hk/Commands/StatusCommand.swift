import Foundation
import HKCore

enum StatusCommand {
    static func run(json: Bool = false) {
        let cpu = CPUMonitor.getCPUInfo()
        let memory = MemoryMonitor.getMemoryInfo()
        let disk = DiskMonitor.getDiskInfo()
        let battery = BatteryMonitor.getBatteryInfo()
        let thermal = ThermalMonitor.getThermalInfo()
        let processes = ProcessMonitor.getTopProcesses(sortBy: .cpu, limit: 8)

        let score = HealthScoreCalculator.calculate(
            cpu: cpu, memory: memory, disk: disk,
            thermal: thermal, battery: battery,
            topProcesses: processes
        )

        if json {
            outputJSON(cpu: cpu, memory: memory, disk: disk,
                       battery: battery, thermal: thermal,
                       processes: processes, score: score)
            return
        }

        let width = 52

        // System gauges section with health score at top
        var gauges: [String] = []

        let scoreColor: Color = switch score.score {
        case 75...100: .boldGreen
        case 50..<75:  .boldYellow
        default:       .boldRed
        }
        gauges.append("\(TerminalUI.colored("Health Score:", .boldWhite)) \(TerminalUI.colored("\(score.score)/100", scoreColor)) \(TerminalUI.colored(score.rating, scoreColor))")
        gauges.append("")

        gauges.append(TerminalUI.gauge(label: "CPU    ", percent: cpu.usagePercent, width: 16))

        let memUsed = ByteFormatter.format(memory.usedBytes)
        let memTotal = ByteFormatter.format(memory.totalBytes)
        gauges.append(TerminalUI.gauge(label: "Memory ", percent: memory.usagePercent, width: 16) + "  \(memUsed)/\(memTotal)")

        let diskUsed = ByteFormatter.format(disk.usedBytes)
        let diskTotal = ByteFormatter.format(disk.totalBytes)
        gauges.append(TerminalUI.gauge(label: "Disk   ", percent: disk.usagePercent, width: 16) + "  \(diskUsed)/\(diskTotal)")

        if battery.available {
            let batteryStatus = battery.isPluggedIn ? "Plugged In" : (battery.isCharging ? "Charging" : "Battery")
            gauges.append(TerminalUI.gauge(label: "Battery", percent: Double(battery.percentage), width: 16, warnAt: 30, critAt: 15) + "  \(batteryStatus)")
        }

        let thermalColor: Color = switch thermal.state {
            case .nominal: .boldGreen
            case .fair: .boldYellow
            case .serious: .boldRed
            case .critical: .boldRed
            case .unknown: .gray
        }
        gauges.append("Thermal: \(TerminalUI.colored(thermal.state.rawValue, thermalColor))")

        gauges.append(TerminalUI.colored("\(cpu.modelName) (\(cpu.coreCount) cores)", .gray))
        gauges.append(TerminalUI.colored(String(format: "Load avg: %.2f  %.2f  %.2f", cpu.loadAverage.0, cpu.loadAverage.1, cpu.loadAverage.2), .gray))

        // Top processes section
        var procs: [String] = []
        procs.append(TerminalUI.colored("Top Processes (CPU):", .boldWhite))
        for (i, proc) in processes.prefix(8).enumerated() {
            let name = String(proc.shortName.prefix(20)).padding(toLength: 20, withPad: " ", startingAt: 0)
            let cpuStr = String(format: "%5.1f%%", proc.cpuPercent)
            let memStr = proc.rssFormatted

            let cpuColor: Color = proc.cpuPercent > 50 ? .boldRed : proc.cpuPercent > 20 ? .boldYellow : .white
            procs.append(" \(i + 1). \(TerminalUI.colored(name, .white)) \(TerminalUI.colored(cpuStr, cpuColor))  \(TerminalUI.colored(memStr, .gray))")
        }

        // Warnings section
        var warnings: [String] = []
        if memory.isSwapHeavy {
            let swapUsed = ByteFormatter.format(memory.swapUsedBytes)
            let swapTotal = ByteFormatter.format(memory.swapTotalBytes)
            warnings.append(TerminalUI.colored("⚠ Swap: \(swapUsed) / \(swapTotal) used", .boldYellow))
        }
        if memory.isPressureHigh {
            warnings.append(TerminalUI.colored("⚠ Memory pressure is HIGH", .boldRed))
        }
        if thermal.state == .serious || thermal.state == .critical {
            warnings.append(TerminalUI.colored("⚠ Thermal state: \(thermal.state.rawValue)", .boldRed))
        }
        for proc in processes.prefix(3) {
            if proc.cpuPercent > 80 {
                warnings.append(TerminalUI.colored("⚠ \(proc.shortName) using \(String(format: "%.0f", proc.cpuPercent))% CPU", .boldRed))
            }
        }

        var sections = [gauges, procs]
        if !warnings.isEmpty {
            sections.append(warnings)
        }

        print(TerminalUI.box(width: width, title: "HOUSEKEEPING", sections: sections))
    }

    private static func outputJSON(cpu: CPUInfo, memory: MemoryInfo, disk: DiskInfo,
                                    battery: BatteryInfo, thermal: ThermalInfo,
                                    processes: [HKProcessInfo], score: HealthScore) {
        struct StatusOutput: Codable {
            let timestamp: Date
            let healthScore: HealthScore
            let cpu: CPUInfo
            let memory: MemoryInfo
            let disk: DiskInfo
            let battery: BatteryInfo
            let thermal: ThermalInfo
            let topProcesses: [HKProcessInfo]
        }

        let output = StatusOutput(
            timestamp: Date(),
            healthScore: score,
            cpu: cpu,
            memory: memory,
            disk: disk,
            battery: battery,
            thermal: thermal,
            topProcesses: processes
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(output),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}
