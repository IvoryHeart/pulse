import Foundation
import PulseCore

enum TrendCommand {
    static func run(json: Bool = false) {
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            let predictions = try TrendAnalyzer.analyzeTrends(store: store)

            if json {
                outputJSON(predictions)
            } else {
                outputTerminal(predictions)
            }
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
        }
    }

    // MARK: - JSON Output

    private static func outputJSON(_ predictions: [TrendAnalyzer.Prediction]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(predictions),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    // MARK: - Terminal Output

    private static func outputTerminal(_ predictions: [TrendAnalyzer.Prediction]) {
        if predictions.isEmpty {
            print()
            print(TerminalUI.colored("  PREDICTIVE TRENDS", .boldCyan))
            print()
            print(TerminalUI.colored("  Not enough history. Run `pulse log` regularly to build trend data.", .yellow))
            print(TerminalUI.colored("  Need at least 10 snapshots over multiple days.", .gray))
            print()
            return
        }

        let width = 56

        var headerLines: [String] = []
        let dataPoints = predictions.first?.dataPoints ?? 0
        let span = predictions.first?.timeSpanDays ?? 0
        headerLines.append(TerminalUI.colored("Based on \(dataPoints) snapshots over \(String(format: "%.1f", span)) days", .gray))

        var criticalLines: [String] = []
        var stableLines: [String] = []

        for pred in predictions {
            let arrow = trendArrow(pred.trend, rate: pred.ratePerDay)
            let confStr = String(format: "%.0f%%", pred.confidence * 100)

            if let daysLeft = pred.daysUntilCritical, pred.trend == .increasing || pred.trend == .decreasing {
                let currentStr = formatValue(pred.currentValue, unit: pred.unit)
                let threshStr = formatValue(pred.criticalThreshold, unit: pred.unit)
                let rateStr = formatRate(pred.ratePerDay, unit: pred.unit)

                let line = "\(metricLabel(pred.metric)): \(currentStr) \(arrow) \(threshStr) in ~\(daysLeft)d"
                let detailLine = "  \(rateStr)/day, confidence: \(confStr)"

                let color: Color = daysLeft < 14 ? .boldRed : daysLeft < 60 ? .boldYellow : .yellow
                criticalLines.append(TerminalUI.colored(line, color))
                criticalLines.append(TerminalUI.colored(detailLine, .gray))

                // Gauge for metrics that use %
                if pred.unit == "%" {
                    criticalLines.append(TerminalUI.gauge(
                        label: "  " + metricLabel(pred.metric).padding(toLength: 8, withPad: " ", startingAt: 0),
                        percent: pred.currentValue, width: 16, warnAt: 70, critAt: 90
                    ))
                }
            } else {
                let currentStr = formatValue(pred.currentValue, unit: pred.unit)
                let rateStr = formatRate(abs(pred.ratePerDay), unit: pred.unit)
                stableLines.append(TerminalUI.colored(
                    "\(metricLabel(pred.metric)): \(currentStr) \(arrow) (\(rateStr)/day, conf: \(confStr))",
                    .gray
                ))
            }
        }

        var sections: [[String]] = [headerLines]
        if !criticalLines.isEmpty {
            sections.append(criticalLines)
        }
        if !stableLines.isEmpty {
            sections.append(stableLines)
        }

        print(TerminalUI.box(width: width, title: "PREDICTIVE TRENDS", sections: sections))
    }

    // MARK: - Formatting Helpers

    private static func trendArrow(_ trend: TrendAnalyzer.Trend, rate: Double) -> String {
        switch trend {
        case .increasing:
            return abs(rate) > 1.0 ? "\u{2191}\u{2191}" : "\u{2191}"    // ↑↑ or ↑
        case .decreasing:
            return abs(rate) > 1.0 ? "\u{2193}\u{2193}" : "\u{2193}"    // ↓↓ or ↓
        case .stable:
            return "\u{2192}"                                             // →
        }
    }

    private static func metricLabel(_ metric: String) -> String {
        switch metric {
        case "disk": return "Disk"
        case "memory": return "Memory"
        case "swap": return "Swap"
        case "health_score": return "Score"
        default: return metric.capitalized
        }
    }

    private static func formatValue(_ value: Double, unit: String) -> String {
        switch unit {
        case "%", "pts":
            return String(format: "%.0f%@", value, unit)
        case "GB":
            return String(format: "%.1f %@", value, unit)
        default:
            return String(format: "%.1f %@", value, unit)
        }
    }

    private static func formatRate(_ rate: Double, unit: String) -> String {
        switch unit {
        case "%", "pts":
            return String(format: "%+.2f%@", rate, unit)
        case "GB":
            return String(format: "%+.3f %@", rate, unit)
        default:
            return String(format: "%+.2f %@", rate, unit)
        }
    }
}