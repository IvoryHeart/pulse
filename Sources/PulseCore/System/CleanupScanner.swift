import Foundation

/// Scans user-owned directories for reclaimable space.
/// Shared by both the CLI (CleanCommand) and SwiftUI app.
public enum CleanupScanner {

    public struct CleanupItem: Sendable {
        public let path: String
        public let sizeBytes: UInt64
        public let description: String
        public let category: String

        public init(path: String, sizeBytes: UInt64, description: String, category: String) {
            self.path = path
            self.sizeBytes = sizeBytes
            self.description = description
            self.category = category
        }
    }

    public struct CleanupReport: Sendable {
        public let items: [CleanupItem]  // sorted by sizeBytes descending, filtered >1MB
        public let totalReclaimableBytes: UInt64
        public let timestamp: Date

        public init(items: [CleanupItem], totalReclaimableBytes: UInt64, timestamp: Date = Date()) {
            self.items = items
            self.totalReclaimableBytes = totalReclaimableBytes
            self.timestamp = timestamp
        }
    }

    /// Scan all cleanup categories and return a report.
    /// This is a potentially slow operation — call from a background thread.
    public static func scan() -> CleanupReport {
        var items: [CleanupItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        scanDirectory("\(home)/Library/Caches", description: "User Caches", category: "Caches", items: &items)
        scanDirectory("\(home)/Library/Logs", description: "User Logs", category: "Logs", items: &items)
        scanDirectory("\(home)/Library/Developer/Xcode/DerivedData", description: "Xcode Derived Data", category: "Dev", items: &items)
        scanDirectory("\(home)/Library/Developer/Xcode/Archives", description: "Xcode Archives", category: "Dev", items: &items)
        scanDirectory("\(home)/Library/Caches/Homebrew", description: "Homebrew Cache", category: "Caches", items: &items)
        scanDirectory("\(home)/.npm/_cacache", description: "npm Cache", category: "Caches", items: &items)
        scanOldDownloads("\(home)/Downloads", days: 30, items: &items)
        scanDirectory("\(home)/.Trash", description: "Trash", category: "Trash", items: &items)

        let sorted = items.filter { $0.sizeBytes > 1024 * 1024 }.sorted { $0.sizeBytes > $1.sizeBytes }
        let total = sorted.reduce(UInt64(0)) { $0 + $1.sizeBytes }

        return CleanupReport(items: sorted, totalReclaimableBytes: total)
    }

    // MARK: - Scanning Helpers

    public static func directorySize(_ path: String) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
        var total: UInt64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = "\(path)/\(file)"
            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? UInt64 {
                total += size
            }
        }
        return total
    }

    private static func scanDirectory(_ path: String, description: String, category: String, items: inout [CleanupItem]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }
        let size = directorySize(path)
        if size > 0 {
            items.append(CleanupItem(path: path, sizeBytes: size, description: description, category: category))
        }
    }

    private static func scanOldDownloads(_ path: String, days: Int, items: inout [CleanupItem]) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return }
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        var totalSize: UInt64 = 0
        var count = 0

        for file in contents {
            let filePath = "\(path)/\(file)"
            guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                  let modDate = attrs[.modificationDate] as? Date,
                  modDate < cutoff else { continue }
            let size = (attrs[.size] as? UInt64) ?? 0
            totalSize += size
            count += 1
        }

        if totalSize > 0 {
            items.append(CleanupItem(path: path, sizeBytes: totalSize, description: "Downloads (>\(days) days, \(count) files)", category: "Downloads"))
        }
    }
}
