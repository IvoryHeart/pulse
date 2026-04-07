import Foundation

public enum ByteFormatter {
    public static func format(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if value == Double(Int(value)) {
            return "\(Int(value)) \(units[unitIndex])"
        }
        return String(format: "%.1f \(units[unitIndex])", value)
    }

    public static func format(_ bytes: Int64) -> String {
        format(UInt64(max(0, bytes)))
    }
}
