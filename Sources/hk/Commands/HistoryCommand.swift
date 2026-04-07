import Foundation
import HKCore

enum HistoryCommand {
    static func run(args: [String]) {
        // Parse --hours flag
        var hours = 24
        if let idx = args.firstIndex(of: "--hours"), idx + 1 < args.count,
           let h = Int(args[args.index(after: idx)]) {
            hours = h
        }
        // Short aliases
        if args.contains("--1h") { hours = 1 }
        if args.contains("--6h") { hours = 6 }
        if args.contains("--12h") { hours = 12 }
        if args.contains("--7d") { hours = 168 }

        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            let points = try store.getHistory(hours: hours, limit: 200)

            if points.isEmpty {
                print(TerminalUI.colored("\n  No history data found.", .yellow))
                print(TerminalUI.colored("  Run 'hk log' to record a snapshot first.\n", .gray))
                return
            }

            let count = try store.getSnapshotCount()
            let periodStr = hours < 24 ? "\(hours)h" : "\(hours / 24)d"

            print(TerminalUI.colored("\n  SYSTEM HISTORY  (last \(periodStr), \(points.count) samples, \(count) total)\n", .boldCyan))

            // CPU sparkline
            let cpuValues = points.map { $0.cpuUsage }
            printSparkline("CPU %    ", values: cpuValues, maxVal: 100, warnAt: 70, critAt: 90)

            // Memory sparkline
            let memValues = points.map { $0.memoryUsage }
            printSparkline("Memory % ", values: memValues, maxVal: 100, warnAt: 80, critAt: 95)

            // Load average sparkline
            let loadValues = points.map { $0.load1m }
            let maxLoad = max(loadValues.max() ?? 10, 10)
            printSparkline("Load 1m  ", values: loadValues, maxVal: maxLoad, warnAt: maxLoad * 0.6, critAt: maxLoad * 0.8)

            // Swap sparkline (in GB)
            let swapValues = points.map { Double($0.swapUsed) / (1024 * 1024 * 1024) }
            let maxSwap = max(swapValues.max() ?? 4, 4)
            printSparkline("Swap GB  ", values: swapValues, maxVal: maxSwap, warnAt: 4, critAt: 8)

            // Battery sparkline
            let battValues = points.map { Double($0.batteryPercent) }
            if battValues.contains(where: { $0 > 0 }) {
                printSparkline("Battery %", values: battValues, maxVal: 100, warnAt: 999, critAt: 999, invertColor: true)
            }

            // Summary stats
            print()
            printSummaryRow("CPU", values: cpuValues, unit: "%")
            printSummaryRow("Memory", values: memValues, unit: "%")
            printSummaryRow("Load", values: loadValues, unit: "")
            printSummaryRow("Swap", values: swapValues, unit: " GB")

            // Time range
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d HH:mm"
            if let first = points.first, let last = points.last {
                print(TerminalUI.colored("  \(fmt.string(from: first.timestamp)) → \(fmt.string(from: last.timestamp))", .gray))
            }

            // Thermal summary
            let thermalCounts = Dictionary(grouping: points, by: { $0.thermalState })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            let thermalStr = thermalCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            print(TerminalUI.colored("  Thermal: \(thermalStr)", .gray))

            print()
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
        }
    }

    // MARK: - Sparkline Charts

    private static let sparkChars: [Character] = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    private static func printSparkline(
        _ label: String,
        values: [Double],
        maxVal: Double,
        warnAt: Double,
        critAt: Double,
        invertColor: Bool = false
    ) {
        // Resample to fit terminal width (~50 chars for the chart)
        let width = 50
        let resampled = resample(values, to: width)

        var chart = ""
        for val in resampled {
            let normalized = min(max(val / maxVal, 0), 1)
            let idx = min(Int(normalized * Double(sparkChars.count - 1)), sparkChars.count - 1)
            chart.append(sparkChars[idx])
        }

        // Color based on current (last) value
        let current = values.last ?? 0
        let color: Color
        if invertColor {
            color = current < 20 ? .boldRed : current < 50 ? .boldYellow : .boldGreen
        } else {
            color = current >= critAt ? .boldRed : current >= warnAt ? .boldYellow : .boldGreen
        }

        let currentStr = String(format: "%5.1f", current)
        print("  \(TerminalUI.colored(label, .boldWhite)) \(TerminalUI.colored(chart, color)) \(TerminalUI.colored(currentStr, color))")
    }

    private static func resample(_ values: [Double], to width: Int) -> [Double] {
        guard values.count > 1 else {
            return Array(repeating: values.first ?? 0, count: width)
        }
        if values.count <= width {
            return values
        }
        var result: [Double] = []
        let step = Double(values.count) / Double(width)
        for i in 0..<width {
            let start = Int(Double(i) * step)
            let end = min(Int(Double(i + 1) * step), values.count)
            let slice = values[start..<end]
            let avg = slice.reduce(0, +) / Double(max(slice.count, 1))
            result.append(avg)
        }
        return result
    }

    private static func printSummaryRow(_ label: String, values: [Double], unit: String) {
        guard !values.isEmpty else { return }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        let avgVal = values.reduce(0, +) / Double(values.count)
        let paddedLabel = label.padding(toLength: 8, withPad: " ", startingAt: 0)
        print("  \(TerminalUI.colored(paddedLabel, .gray)) min: \(String(format: "%.1f", minVal))\(unit)  avg: \(String(format: "%.1f", avgVal))\(unit)  max: \(String(format: "%.1f", maxVal))\(unit)")
    }
}
