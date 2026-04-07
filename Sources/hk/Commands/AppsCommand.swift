import Foundation
import HKCore

enum AppsCommand {
    static func run(args: [String], json: Bool = false) {
        // Parse time period from args
        var days = 7
        if args.contains("--1d") { days = 1 }
        if args.contains("--30d") { days = 30 }
        if args.contains("--7d") { days = 7 }

        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            let profiles = try AppProfiler.getProfiles(store: store, days: days)

            if profiles.isEmpty {
                if json {
                    print("[]")
                } else {
                    print(TerminalUI.colored("\n  No process history found.", .yellow))
                    print(TerminalUI.colored("  Run `hk log` regularly to build app profiles.\n", .gray))
                }
                return
            }

            if json {
                outputJSON(profiles)
            } else {
                outputTerminal(profiles, days: days)
            }
        } catch {
            if json {
                print("{\"error\": \"\(error.localizedDescription)\"}")
            } else {
                print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
            }
        }
    }

    // MARK: - JSON Output

    private static func outputJSON(_ profiles: [AppProfiler.AppProfile]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(profiles),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    // MARK: - Terminal Output

    private static func outputTerminal(_ profiles: [AppProfiler.AppProfile], days: Int) {
        let periodStr = days == 1 ? "Last 24 Hours" : "Last \(days) Days"
        let width = 58

        print(TerminalUI.colored("\n  APP ENERGY REPORT (\(periodStr))\n", .boldCyan))

        // Build rows for the box
        var rows: [String] = []

        let header = "\(pad("Grade", 7))\(pad("App", 18))\(pad("CPU-hrs", 10))\(pad("Avg CPU", 9))\(pad("Peak", 6))\("Mem")"
        rows.append(TerminalUI.colored(header, .boldWhite))
        rows.append(TerminalUI.colored(String(repeating: "\u{2500}", count: 54), .gray))

        for profile in profiles {
            let gradeColor = gradeColor(profile.grade)
            let gradeStr = TerminalUI.colored(" [\(profile.grade)]  ", gradeColor)

            let name = String(profile.name.prefix(16)).padding(toLength: 16, withPad: " ", startingAt: 0)

            let cpuHrsStr: String
            if profile.cpuHours >= 100 {
                cpuHrsStr = String(format: "%6.0fh", profile.cpuHours)
            } else if profile.cpuHours >= 10 {
                cpuHrsStr = String(format: "%6.1fh", profile.cpuHours)
            } else {
                cpuHrsStr = String(format: "%6.2fh", profile.cpuHours)
            }

            let avgCpuStr = String(format: "%5.1f%%", profile.avgCpuPercent)
            let peakCpuStr = String(format: "%3.0f%%", profile.peakCpuPercent)
            let memStr = formatMemory(profile.avgMemoryMB)

            rows.append("\(gradeStr)\(name)  \(cpuHrsStr)  \(avgCpuStr)  \(peakCpuStr)  \(memStr)")
        }

        print(TerminalUI.box(width: width, title: "Top Apps by CPU Usage", sections: [rows]))

        // Summary
        let totalCpuHours = profiles.reduce(0.0) { $0 + $1.cpuHours }
        let appCount = profiles.count

        print()
        print(TerminalUI.colored("  Summary:", .boldWhite))

        let totalStr = String(format: "%.1f", totalCpuHours)
        print("  Total CPU-hours tracked: \(TerminalUI.colored("\(totalStr)h", .boldWhite)) across \(TerminalUI.colored("\(appCount) apps", .boldWhite))")

        if let most = profiles.last(where: { $0.grade == "A" }) ?? profiles.min(by: { $0.cpuHours < $1.cpuHours }) {
            let cpuStr = String(format: "%.1f", most.cpuHours)
            print("  Most efficient: \(TerminalUI.colored(most.name, .boldGreen)) (Grade \(most.grade), \(cpuStr) CPU-hrs)")
        }

        if let biggest = profiles.first {
            let cpuStr = String(format: "%.1f", biggest.cpuHours)
            let color = gradeColor(biggest.grade)
            print("  Biggest consumer: \(TerminalUI.colored(biggest.name, color)) (Grade \(biggest.grade), \(cpuStr) CPU-hrs)")
        }

        print()
    }

    // MARK: - Helpers

    private static func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .boldGreen
        case "B": return .blue
        case "C": return .boldYellow
        case "D": return .yellow
        case "F": return .boldRed
        default:  return .gray
        }
    }

    private static func pad(_ str: String, _ width: Int) -> String {
        str.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    private static func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1fG", mb / 1024)
        } else if mb >= 100 {
            return String(format: "%.0fM", mb)
        } else {
            return String(format: "%.1fM", mb)
        }
    }
}