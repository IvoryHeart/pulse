import Foundation
import HKCore

enum LogCommand {
    static func run(args: [String]) {
        if args.contains("--prune") {
            runPrune()
            return
        }
        if args.contains("--info") {
            runInfo()
            return
        }
        recordSnapshot()
    }

    private static func recordSnapshot() {
        let cpu = CPUMonitor.getCPUInfo()
        let memory = MemoryMonitor.getMemoryInfo()
        let disk = DiskMonitor.getDiskInfo()
        let battery = BatteryMonitor.getBatteryInfo()
        let thermal = ThermalMonitor.getThermalInfo()
        let processes = ProcessMonitor.getTopProcesses(sortBy: .cpu, limit: 10)

        let snapshot = HealthSnapshot(
            cpu: cpu,
            memory: memory,
            disk: disk,
            battery: battery,
            thermal: thermal,
            topProcesses: processes
        )

        let score = HealthScoreCalculator.calculate(
            cpu: cpu, memory: memory, disk: disk,
            thermal: thermal, battery: battery,
            topProcesses: processes
        )

        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }
            try store.saveSnapshot(snapshot, healthScore: score.score)

            let count = try store.getSnapshotCount()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeStr = formatter.string(from: snapshot.timestamp)

            print(TerminalUI.colored("  Snapshot recorded at \(timeStr)  Score: \(score.score)/100", .green))
            print(TerminalUI.colored("  CPU: \(String(format: "%.0f%%", cpu.usagePercent))  Mem: \(String(format: "%.0f%%", memory.usagePercent))  Swap: \(ByteFormatter.format(memory.swapUsedBytes))  Thermal: \(thermal.state.rawValue)", .gray))
            print(TerminalUI.colored("  Total snapshots: \(count)  DB: ~/.hk/health.db", .gray))
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
        }
    }

    private static func runInfo() {
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            let count = try store.getSnapshotCount()
            print(TerminalUI.colored("\n  Log Database Info\n", .boldCyan))
            print("  Database: \(TerminalUI.colored(HealthStore.dbPath, .gray))")
            print("  Snapshots: \(TerminalUI.colored("\(count)", .boldWhite))")

            if let range = try store.getTimeRange() {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd HH:mm"
                print("  First: \(TerminalUI.colored(fmt.string(from: range.first), .gray))")
                print("  Last:  \(TerminalUI.colored(fmt.string(from: range.last), .gray))")
                let hours = Int(range.last.timeIntervalSince(range.first) / 3600)
                print("  Span:  \(TerminalUI.colored("\(hours) hours", .gray))")
            }
            print()
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
        }
    }

    private static func runPrune() {
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            let before = try store.getSnapshotCount()
            let deleted = try store.prune(keepDays: 30)
            let after = try store.getSnapshotCount()

            print(TerminalUI.colored("  Pruned \(deleted) snapshots older than 30 days", .green))
            print(TerminalUI.colored("  Before: \(before)  After: \(after)", .gray))
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
        }
    }
}
