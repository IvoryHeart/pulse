import Foundation
import Darwin

public struct DiskMonitor {

    // MARK: - Public API

    public static func getDiskInfo() -> DiskInfo {
        var stat = statvfs()
        guard statvfs("/", &stat) == 0 else {
            return DiskInfo(totalBytes: 0, usedBytes: 0, availableBytes: 0)
        }

        let total = UInt64(stat.f_frsize) * UInt64(stat.f_blocks)
        let available = UInt64(stat.f_frsize) * UInt64(stat.f_bavail)
        let used = total - available

        return DiskInfo(
            totalBytes: total,
            usedBytes: used,
            availableBytes: available
        )
    }
}
