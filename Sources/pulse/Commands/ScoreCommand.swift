import Foundation
import PulseCore

enum ScoreCommand {
    static func run(json: Bool = false) {
        let cpu = CPUMonitor.getCPUInfo()
        let memory = MemoryMonitor.getMemoryInfo()
        let disk = DiskMonitor.getDiskInfo()
        let battery = BatteryMonitor.getBatteryInfo()
        let thermal = ThermalMonitor.getThermalInfo()
        let processes = ProcessMonitor.getTopProcesses(sortBy: .cpu, limit: 10)

        let score = HealthScoreCalculator.calculate(
            cpu: cpu, memory: memory, disk: disk,
            thermal: thermal, battery: battery,
            topProcesses: processes
        )

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(score),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            outputTerminal(score)
        }
    }

    private static func outputTerminal(_ score: HealthScore) {
        let width = 52

        let scoreColor: Color = switch score.score {
        case 75...100: .boldGreen
        case 50..<75:  .boldYellow
        default:       .boldRed
        }

        var header: [String] = []
        header.append("\(TerminalUI.colored("Health Score:", .boldWhite)) \(TerminalUI.colored("\(score.score)/100", scoreColor))  \(TerminalUI.colored(score.rating, scoreColor))")
        header.append(TerminalUI.gauge(label: "Health ", percent: Double(score.score), width: 16, warnAt: 50, critAt: 25))

        var deductionLines: [String] = []
        if score.deductions.isEmpty {
            deductionLines.append(TerminalUI.colored("No issues detected. System is healthy!", .green))
        } else {
            deductionLines.append(TerminalUI.colored("Deductions:", .boldWhite))
            for d in score.deductions.sorted(by: { $0.penalty > $1.penalty }) {
                let penaltyStr = String(format: "-%d", d.penalty)
                let catStr = d.category.padding(toLength: 10, withPad: " ", startingAt: 0)
                deductionLines.append(
                    "  \(TerminalUI.colored(penaltyStr, .boldRed))  \(TerminalUI.colored(catStr, .cyan)) \(d.label)"
                )
                deductionLines.append(
                    "        \(TerminalUI.colored(d.explanation, .gray))"
                )
            }
        }

        print(TerminalUI.box(width: width, title: "HEALTH SCORE", sections: [header, deductionLines]))
    }
}
