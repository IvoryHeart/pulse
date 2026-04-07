import Foundation
import HKCore

enum HotCommand {
    static func run() {
        print(TerminalUI.colored("\n  HOT PROCESS FINDER\n", .boldCyan))

        let memory = MemoryMonitor.getMemoryInfo()
        let cpuProcs = ProcessMonitor.getTopProcesses(sortBy: .cpu, limit: 10)
        let memProcs = ProcessMonitor.getTopProcesses(sortBy: .memory, limit: 10)

        // CPU hogs
        let hotCPU = cpuProcs.filter { $0.cpuPercent > 10 }
        if !hotCPU.isEmpty {
            print(TerminalUI.colored("  CPU Intensive Processes:", .boldYellow))
            print(TerminalUI.colored("  " + String(repeating: "─", count: 48), .gray))
            for proc in hotCPU {
                let name = String(proc.shortName.prefix(25)).padding(toLength: 25, withPad: " ", startingAt: 0)
                let cpuStr = String(format: "%5.1f%%", proc.cpuPercent)
                let severity: Color = proc.cpuPercent > 50 ? .boldRed : proc.cpuPercent > 25 ? .boldYellow : .yellow
                print("  \(TerminalUI.colored("●", severity)) \(name) \(TerminalUI.colored(cpuStr, severity))  \(TerminalUI.colored(proc.rssFormatted, .gray))")
            }
        } else {
            print(TerminalUI.colored("  ✓ No processes with unusually high CPU usage", .green))
        }

        print()

        // Memory hogs (>500MB RSS)
        let hotMem = memProcs.filter { $0.rssBytes > 500 * 1024 * 1024 }
        if !hotMem.isEmpty {
            print(TerminalUI.colored("  Memory Intensive Processes:", .boldYellow))
            print(TerminalUI.colored("  " + String(repeating: "─", count: 48), .gray))
            for proc in hotMem {
                let name = String(proc.shortName.prefix(25)).padding(toLength: 25, withPad: " ", startingAt: 0)
                let severity: Color = proc.rssBytes > 2 * 1024 * 1024 * 1024 ? .boldRed : .boldYellow
                print("  \(TerminalUI.colored("●", severity)) \(name) \(TerminalUI.colored(proc.rssFormatted, severity))")
            }
        } else {
            print(TerminalUI.colored("  ✓ No processes with unusually high memory usage", .green))
        }

        print()

        // Swap analysis
        if memory.isSwapHeavy {
            let swapUsed = ByteFormatter.format(memory.swapUsedBytes)
            let swapTotal = ByteFormatter.format(memory.swapTotalBytes)
            print(TerminalUI.colored("  ⚠ Swap Pressure: \(swapUsed) / \(swapTotal)", .boldRed))
            print(TerminalUI.colored("    Your system is heavily swapping. This causes heat and slowness.", .yellow))
            print(TerminalUI.colored("    Suggestion: Close memory-heavy apps to reduce swap usage.", .gray))
        } else if memory.swapUsedBytes > 1024 * 1024 * 1024 {
            let swapUsed = ByteFormatter.format(memory.swapUsedBytes)
            print(TerminalUI.colored("  △ Swap Usage: \(swapUsed)", .yellow))
            print(TerminalUI.colored("    Moderate swap usage. Monitor if system feels slow.", .gray))
        } else {
            print(TerminalUI.colored("  ✓ Swap usage is healthy", .green))
        }

        print()

        // Suggestions
        print(TerminalUI.colored("  Suggestions:", .boldWhite))
        print(TerminalUI.colored("  " + String(repeating: "─", count: 48), .gray))

        var hasSuggestions = false

        // Suggest closing high CPU processes
        for proc in hotCPU.prefix(3) {
            if proc.cpuPercent > 30 {
                hasSuggestions = true
                let memStr = proc.rssFormatted
                print("  → Consider restarting \(TerminalUI.colored(proc.shortName, .boldWhite)) (\(String(format: "%.0f", proc.cpuPercent))% CPU, \(memStr) RAM)")
            }
        }

        // Count browsers
        let browserNames = ["Safari", "Chrome", "Arc", "Brave", "Firefox", "Edge", "Opera"]
        var runningBrowsers: [String] = []
        for proc in cpuProcs + memProcs {
            for browser in browserNames {
                if proc.name.localizedCaseInsensitiveContains(browser) && !runningBrowsers.contains(browser) {
                    runningBrowsers.append(browser)
                }
            }
        }
        if runningBrowsers.count > 1 {
            hasSuggestions = true
            print("  → You have \(runningBrowsers.count) browsers running (\(runningBrowsers.joined(separator: ", "))). Consider closing some.")
        }

        if memory.isPressureHigh {
            hasSuggestions = true
            print("  → Memory pressure is high. Closing unused apps will help reduce heat.")
        }

        if !hasSuggestions {
            print(TerminalUI.colored("  ✓ System looks healthy! No immediate actions needed.", .green))
        }

        print()
    }
}
