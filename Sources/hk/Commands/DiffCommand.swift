import Foundation
import HKCore

enum DiffCommand {
    static func run(args: [String], json: Bool = false) {
        var daysAgo = 7
        for arg in args {
            switch arg {
            case "--1d": daysAgo = 1
            case "--7d": daysAgo = 7
            case "--14d": daysAgo = 14
            case "--30d": daysAgo = 30
            default:
                if arg.hasPrefix("--") && arg.hasSuffix("d"),
                   let n = Int(arg.dropFirst(2).dropLast(1)), n > 0 { daysAgo = n }
            }
        }
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }
            guard let diff = try TimeTravelDiff.compare(store: store, daysAgo: daysAgo) else {
                if json { print("{\"error\": \"no_data\"}") } else {
                    print()
                    print(TerminalUI.colored("  No snapshot found near \(daysAgo) day(s) ago.", .yellow))
                    print(TerminalUI.colored("  Run `hk log` regularly to build history.", .gray))
                    print()
                }
                return
            }
            if json { outputJSON(diff) } else { outputTerminal(diff, daysAgo: daysAgo) }
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
        }
    }

    private static func outputJSON(_ diff: TimeTravelDiff.SystemDiff) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(diff),
           let str = String(data: data, encoding: .utf8) { print(str) }
    }

    private static func outputTerminal(_ diff: TimeTravelDiff.SystemDiff, daysAgo: Int) {
        let width = 58
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, HH:mm"
        var headerLines: [String] = []
        headerLines.append(TerminalUI.colored(
            "Now: \(fmt.string(from: diff.currentTimestamp))  vs  Then: \(fmt.string(from: diff.comparisonTimestamp))", .gray))
        var metricLines: [String] = []
        for change in diff.changes {
            let label = change.metric.padding(toLength: 14, withPad: " ", startingAt: 0)
            let oldStr = fmtVal(change.oldValue, unit: change.unit)
            let newStr = fmtVal(change.newValue, unit: change.unit)
            let deltaStr = fmtDelta(change.newValue - change.oldValue, unit: change.unit)
            let arrow = changeArrow(change)
            let color = changeColor(change)
            metricLines.append("\(TerminalUI.colored(label, .boldWhite))  \(oldStr) \u{2192} \(newStr)  \(TerminalUI.colored(deltaStr, color))  \(TerminalUI.colored(arrow, color))")
        }
        var processLines: [String] = []
        if !diff.newProcesses.isEmpty {
            processLines.append(TerminalUI.colored("New since then: ", .boldWhite) + TerminalUI.colored(diff.newProcesses.prefix(8).joined(separator: ", "), .green))
        }
        if !diff.goneProcesses.isEmpty {
            processLines.append(TerminalUI.colored("No longer running: ", .boldWhite) + TerminalUI.colored(diff.goneProcesses.prefix(8).joined(separator: ", "), .gray))
        }
        if diff.newProcesses.isEmpty && diff.goneProcesses.isEmpty {
            processLines.append(TerminalUI.colored("Top processes: no changes detected", .gray))
        }
        var sections: [[String]] = [headerLines, metricLines]
        if !processLines.isEmpty { sections.append(processLines) }
        if let delta = diff.scoreChange {
            let sign = delta >= 0 ? "+" : ""
            let color: Color = delta > 0 ? .boldGreen : delta < 0 ? .boldRed : .gray
            sections.append([TerminalUI.colored("Health score change: \(sign)\(delta) points", color)])
        }
        print(TerminalUI.box(width: width, title: "SYSTEM DIFF vs \(diff.timeSpan.uppercased())", sections: sections))
    }

    private static func fmtVal(_ value: Double, unit: String) -> String {
        switch unit {
        case "%", "pts": return String(format: "%.0f%@", value, unit)
        case "GB": return String(format: "%.1f %@", value, unit)
        default: return String(format: "%.1f", value)
        }
    }

    private static func fmtDelta(_ delta: Double, unit: String) -> String {
        let sign = delta >= 0 ? "+" : ""
        switch unit {
        case "%", "pts": return "(\(sign)\(String(format: "%.0f", delta))\(unit))"
        case "GB": return "(\(sign)\(String(format: "%.1f", delta)) \(unit))"
        default: return "(\(sign)\(String(format: "%.1f", delta)))"
        }
    }

    private static func changeArrow(_ c: TimeTravelDiff.MetricChange) -> String {
        switch c.significance {
        case .major: return c.changePercent > 0 ? "\u{2191}\u{2191}" : "\u{2193}\u{2193}"
        case .minor: return c.changePercent > 0 ? "\u{2191}" : "\u{2193}"
        case .negligible: return "\u{2192}"
        }
    }

    private static func changeColor(_ c: TimeTravelDiff.MetricChange) -> Color {
        switch c.significance {
        case .major:
            if c.metric == "Health Score" || c.metric == "Battery" {
                return c.changePercent < 0 ? .boldRed : .boldGreen
            }
            return c.changePercent > 0 ? .boldRed : .boldGreen
        case .minor: return .yellow
        case .negligible: return .gray
        }
    }
}