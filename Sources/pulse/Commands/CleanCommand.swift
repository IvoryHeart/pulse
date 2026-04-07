import Foundation
import PulseCore

enum CleanCommand {
    // Paths that should NEVER be deleted even if scanned
    private static let protectedPaths: Set<String> = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            home,
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Library",
            "\(home)/Pictures",
            "\(home)/Music",
            "/",
            "/System",
            "/Applications",
            "/usr",
            "/var",
        ]
    }()

    static func run(confirm: Bool = false) {
        print(TerminalUI.colored("\n  CLEANUP SCANNER\n", .boldCyan))
        print(TerminalUI.colored("  Safety: All operations require explicit per-item permission.", .gray))
        print(TerminalUI.colored("  No sudo commands. No system files. No silent deletions.\n", .gray))

        if !confirm {
            print(TerminalUI.colored("  Mode: DRY RUN (scan only, nothing will be deleted)\n", .gray))
        } else {
            print(TerminalUI.colored("  Mode: INTERACTIVE (you approve each deletion individually)\n", .boldYellow))
        }

        let report = CleanupScanner.scan()
        let sortedItems = report.items
        var totalSize: UInt64 = 0

        if sortedItems.isEmpty {
            print(TerminalUI.colored("  Nothing significant to clean up!\n", .green))
            return
        }

        let header = "  \("Category".padding(toLength: 10, withPad: " ", startingAt: 0)) \("Description".padding(toLength: 28, withPad: " ", startingAt: 0)) Size"
        print(TerminalUI.colored(header, .boldWhite))
        print(TerminalUI.colored("  " + String(repeating: "─", count: 52), .gray))

        for item in sortedItems {
            guard item.sizeBytes > 1024 * 1024 else { continue }
            totalSize += item.sizeBytes
            let cat = item.category.padding(toLength: 10, withPad: " ", startingAt: 0)
            let desc = item.description.padding(toLength: 28, withPad: " ", startingAt: 0)
            let size = ByteFormatter.format(item.sizeBytes)
            let sizeColor: Color = item.sizeBytes > 1024 * 1024 * 1024 ? .boldRed : item.sizeBytes > 100 * 1024 * 1024 ? .boldYellow : .white
            print("  \(TerminalUI.colored(cat, .cyan)) \(desc) \(TerminalUI.colored(size, sizeColor))")
        }

        print(TerminalUI.colored("  " + String(repeating: "─", count: 52), .gray))
        print("  \(TerminalUI.colored("Total reclaimable:", .boldWhite)) \(TerminalUI.colored(ByteFormatter.format(totalSize), .boldGreen))")

        if !confirm {
            print(TerminalUI.colored("\n  This was a dry run. No files were touched.", .gray))
            print(TerminalUI.colored("  Run 'pulse clean --confirm' to clean with per-item confirmation.\n", .gray))
        } else {
            interactiveCleanup(sortedItems)
        }
    }

    private static func interactiveCleanup(_ items: [CleanupScanner.CleanupItem]) {
        let cleanableItems = items.filter { $0.sizeBytes > 1024 * 1024 }
        guard !cleanableItems.isEmpty else { return }

        print(TerminalUI.colored("\n  Interactive cleanup (\(cleanableItems.count) items):", .boldWhite))
        print(TerminalUI.colored("  For each item, you must type 'yes' (full word) to confirm deletion.", .gray))
        print(TerminalUI.colored("  Type 'quit' to stop at any time.\n", .gray))

        var deletedCount = 0
        var deletedBytes: UInt64 = 0

        for (index, item) in cleanableItems.enumerated() {
            // Safety: verify path is allowed
            guard isPathSafeToDelete(item.path) else {
                print(TerminalUI.colored("  BLOCKED: \(item.path) is a protected path. Skipping.", .boldRed))
                continue
            }

            let sizeStr = ByteFormatter.format(item.sizeBytes)
            print("  [\(index + 1)/\(cleanableItems.count)] \(TerminalUI.colored(item.description, .boldWhite)) (\(sizeStr))")
            print("  Path: \(TerminalUI.colored(item.path, .gray))")
            print("  Delete? Type '\(TerminalUI.colored("yes", .boldYellow))' to confirm, Enter to skip, 'quit' to stop: ", terminator: "")
            fflush(stdout)

            guard let answer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() else {
                print(TerminalUI.colored("  Skipped", .gray))
                continue
            }

            if answer == "quit" || answer == "q" {
                print(TerminalUI.colored("\n  Stopped by user.", .gray))
                break
            }

            if answer == "yes" {
                // Double-check: show full path and ask one more time for large deletions (>1GB)
                if item.sizeBytes > 1024 * 1024 * 1024 {
                    print("  \(TerminalUI.colored("WARNING:", .boldRed)) This will delete \(sizeStr) from:")
                    print("  \(item.path)")
                    print("  Are you absolutely sure? Type '\(TerminalUI.colored("yes", .boldRed))': ", terminator: "")
                    fflush(stdout)
                    guard readLine()?.trimmingCharacters(in: .whitespaces).lowercased() == "yes" else {
                        print(TerminalUI.colored("  Skipped", .gray))
                        continue
                    }
                }

                do {
                    try FileManager.default.removeItem(atPath: item.path)
                    print(TerminalUI.colored("  Deleted \(sizeStr)", .green))
                    deletedCount += 1
                    deletedBytes += item.sizeBytes
                } catch {
                    print(TerminalUI.colored("  Failed: \(error.localizedDescription)", .red))
                }
            } else {
                print(TerminalUI.colored("  Skipped", .gray))
            }
            print()
        }

        print(TerminalUI.colored("  " + String(repeating: "─", count: 52), .gray))
        if deletedCount > 0 {
            print("  \(TerminalUI.colored("Cleaned:", .boldGreen)) \(deletedCount) items, \(ByteFormatter.format(deletedBytes)) freed")
        } else {
            print(TerminalUI.colored("  No items were deleted.", .gray))
        }
        print()
    }

    private static func isPathSafeToDelete(_ path: String) -> Bool {
        let resolved = (path as NSString).standardizingPath

        // Never delete protected paths
        if protectedPaths.contains(resolved) { return false }

        // Must be under user's home directory
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard resolved.hasPrefix(home) else { return false }

        // Must not be a top-level home directory
        let relative = String(resolved.dropFirst(home.count + 1))
        let components = relative.components(separatedBy: "/")
        if components.count <= 1 && !["Library", ".Trash", ".npm"].contains(components.first ?? "") {
            // Don't delete top-level folders like Documents, Desktop, etc.
            return false
        }

        return true
    }

}
