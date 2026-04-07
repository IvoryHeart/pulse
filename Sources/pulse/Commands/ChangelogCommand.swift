import Foundation
import PulseCore

enum ChangelogCommand {
    static func run(args: [String], json: Bool = false) {
        // Subcommand routing
        if args.first == "scan" {
            runScan(json: json)
            return
        }

        // Parse --Nd flags for day filtering
        var days = 7
        for arg in args {
            if arg.hasPrefix("--") && arg.hasSuffix("d") {
                let numStr = String(arg.dropFirst(2).dropLast(1))
                if let n = Int(numStr) {
                    days = n
                }
            }
        }

        showChangelog(days: days, json: json)
    }

    // MARK: - Scan subcommand

    private static func runScan(json: Bool) {
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }
            try store.createChangelogTables()

            // Check if this is the first run
            let previousState = try store.getLastSystemState()
            let isFirstRun = previousState == nil

            if !isFirstRun {
                // Detect and record changes
                let changes = try ChangelogMonitor.detectChanges(store: store)
                for entry in changes {
                    try store.saveChangelogEntry(entry)
                }

                if json {
                    outputJSON(changes)
                } else if changes.isEmpty {
                    print(TerminalUI.colored("\n  No changes detected since last scan.\n", .gray))
                } else {
                    print(TerminalUI.colored("\n  Scan complete: \(changes.count) change(s) detected.\n", .green))
                    printChanges(changes)
                }
            }

            // Save the new baseline
            try ChangelogMonitor.saveCurrentState(store: store)

            if isFirstRun {
                if json {
                    outputJSON([])
                } else {
                    print(TerminalUI.colored("\n  First scan - recording baseline.", .yellow))
                    print(TerminalUI.colored("  Run `pulse changelog` again later to see changes.\n", .gray))
                }
            }
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
        }
    }

    // MARK: - Show changelog

    private static func showChangelog(days: Int, json: Bool) {
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }
            try store.createChangelogTables()

            let entries = try store.getChangelog(days: days)

            if json {
                outputJSON(entries)
                return
            }

            if entries.isEmpty {
                let previousState = try store.getLastSystemState()
                if previousState == nil {
                    print(TerminalUI.colored("\n  No changelog data yet.", .yellow))
                    print(TerminalUI.colored("  Run `pulse changelog scan` to record a baseline.\n", .gray))
                } else {
                    print(TerminalUI.colored("\n  No changes in the last \(days) day(s).\n", .gray))
                }
                return
            }

            print(TerminalUI.colored("\n  SYSTEM CHANGELOG\n", .boldCyan))
            printChanges(entries)
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)", .red))
        }
    }

    // MARK: - Display helpers

    private static func printChanges(_ entries: [ChangelogMonitor.ChangeEntry]) {
        // Group entries by calendar day
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }

        let sortedDays = grouped.keys.sorted(by: >)

        for day in sortedDays {
            guard let dayEntries = grouped[day] else { continue }

            let label = relativeDateLabel(for: day)
            print("  \(TerminalUI.colored(label, .boldWhite))")
            print("  \(TerminalUI.colored(String(repeating: "\u{2500}", count: 45), .gray))")

            for entry in dayEntries.sorted(by: { $0.item < $1.item }) {
                let (symbol, color) = symbolAndColor(for: entry.action)
                let categoryTag = categoryTag(for: entry.category)
                let itemStr = entry.item.padding(toLength: 28, withPad: " ", startingAt: 0)
                let detailStr = entry.details ?? ""

                print("  \(TerminalUI.colored(symbol, color)) \(TerminalUI.colored(categoryTag, .gray))  \(TerminalUI.colored(itemStr, .white))  \(TerminalUI.colored(detailStr, color))")
            }
            print()
        }
    }

    private static func symbolAndColor(for action: ChangelogMonitor.Action) -> (String, Color) {
        switch action {
        case .added:    return ("+", .green)
        case .removed:  return ("-", .red)
        case .modified: return ("~", .yellow)
        }
    }

    private static func categoryTag(for category: ChangelogMonitor.Category) -> String {
        switch category {
        case .application:       return "[App]   "
        case .launchAgent:       return "[Agent] "
        case .launchDaemon:      return "[Daemon]"
        case .loginItem:         return "[Login] "
        case .browserExtension:  return "[Ext]   "
        case .systemPreference:  return "[Pref]  "
        }
    }

    private static func relativeDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        let dayDiff = calendar.dateComponents([.day], from: date, to: startOfToday).day ?? 0

        switch dayDiff {
        case 0:  return "Today"
        case 1:  return "Yesterday"
        case 2...6:
            return "\(dayDiff) days ago"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    // MARK: - JSON output

    private static func outputJSON(_ entries: [ChangelogMonitor.ChangeEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}