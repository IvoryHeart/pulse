import Foundation
import PulseCore

enum ArchiveCommand {
    static func run(args: [String], json: Bool = false) {
        let subcommand = args.first ?? "status"

        switch subcommand {
        case "run":
            runArchive()
        case "export":
            let days = parseDays(args) ?? 7
            exportData(days: days, json: true)
        case "stats", "status":
            showStats(json: json)
        default:
            showStats(json: json)
        }
    }

    // MARK: - Stats

    private static func showStats(json: Bool) {
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            let stats = try store.getDatabaseStats()

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(stats),
                   let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
                return
            }

            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d, yyyy"

            let sizeMB = String(format: "%.1f MB", Double(stats.fileSizeBytes) / 1_000_000.0)
            let oldest = stats.oldestSnapshot.map { fmt.string(from: $0) } ?? "none"
            let newest = stats.newestSnapshot.map { fmt.string(from: $0) } ?? "none"

            var statusLines: [String] = []
            statusLines.append("\(TerminalUI.colored("Location:", .boldWhite))    ~/.pulse/health.db")
            statusLines.append("\(TerminalUI.colored("Size:", .boldWhite))        \(sizeMB)")
            statusLines.append("\(TerminalUI.colored("Snapshots:", .boldWhite))   \(formatNumber(stats.snapshotCount)) (oldest: \(oldest), newest: \(newest))")
            statusLines.append("\(TerminalUI.colored("Processes:", .boldWhite))   \(formatNumber(stats.processRecordCount)) records")
            statusLines.append("\(TerminalUI.colored("Devices:", .boldWhite))     \(formatNumber(stats.deviceRecordCount)) sightings")
            statusLines.append("\(TerminalUI.colored("Archived:", .boldWhite))    \(stats.archivedDaysCount) daily summaries")

            print(TerminalUI.colored("\n  DATABASE MAINTENANCE\n", .boldCyan))
            print(TerminalUI.box(width: 60, title: "Database Status", sections: [statusLines]))
            print()

            // Recommendation
            if stats.snapshotCount > 500 {
                let archivable = stats.snapshotCount
                var recLines: [String] = []
                recLines.append("\(formatNumber(archivable)) snapshots can potentially be archived.")
                recLines.append("Run \(TerminalUI.colored("pulse archive run", .cyan)) to compress and reclaim space.")
                print(TerminalUI.box(width: 60, title: "Recommendation", sections: [recLines]))
                print()
            } else if stats.fileSizeBytes > 50_000_000 {
                var recLines: [String] = []
                recLines.append("Database is over 50 MB.")
                recLines.append("Run \(TerminalUI.colored("pulse archive run", .cyan)) to archive old data.")
                print(TerminalUI.box(width: 60, title: "Recommendation", sections: [recLines]))
                print()
            } else {
                print(TerminalUI.colored("  Database looks healthy. No action needed.\n", .green))
            }
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)\n", .red))
        }
    }

    // MARK: - Run Archive

    private static func runArchive() {
        print(TerminalUI.colored("\n  ARCHIVING OLD DATA\n", .boldCyan))

        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            let sizeBefore = try store.getDatabaseSize()
            print(TerminalUI.colored("  Archiving snapshots older than 14 days...", .gray))

            let result = try store.archiveOldData(olderThanDays: 14)

            if result.archivedDays == 0 {
                print(TerminalUI.colored("  No data old enough to archive.\n", .yellow))
                return
            }

            print("  \(TerminalUI.colored("✓", .boldGreen)) Archived \(result.archivedDays) days → \(result.archivedDays) daily summaries")
            print("  \(TerminalUI.colored("✓", .boldGreen)) Removed \(formatNumber(result.deletedSnapshots)) detailed snapshots")

            print(TerminalUI.colored("\n  Running VACUUM to reclaim space...", .gray))
            try store.vacuum()

            let sizeAfter = try store.getDatabaseSize()
            let beforeMB = String(format: "%.1f MB", Double(sizeBefore) / 1_000_000.0)
            let afterMB = String(format: "%.1f MB", Double(sizeAfter) / 1_000_000.0)
            let savedMB = String(format: "%.1f MB", Double(max(0, sizeBefore - sizeAfter)) / 1_000_000.0)

            print("  \(TerminalUI.colored("✓", .boldGreen)) Database size: \(beforeMB) → \(afterMB) (saved \(savedMB))")
            print(TerminalUI.colored("\n  Done! Your database is clean and compact.\n", .boldGreen))
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)\n", .red))
        }
    }

    // MARK: - Export

    private static func exportData(days: Int, json: Bool) {
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            let exported = try store.exportData(days: days)
            print(exported)
        } catch {
            print(TerminalUI.colored("  Error: \(error.localizedDescription)\n", .red))
        }
    }

    // MARK: - Helpers

    private static func parseDays(_ args: [String]) -> Int? {
        for arg in args {
            if arg == "--1d" { return 1 }
            if arg == "--7d" { return 7 }
            if arg == "--30d" { return 30 }
            if arg == "--90d" { return 90 }
        }
        return nil
    }

    private static func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
