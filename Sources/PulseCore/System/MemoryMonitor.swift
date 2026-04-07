import Foundation
import Darwin

public struct MemoryMonitor {

    // MARK: - Public API

    public static func getMemoryInfo() -> MemoryInfo {
        let totalBytes = getTotalMemory()
        let (used, wired, compressed) = getVMStatistics(totalBytes: totalBytes)
        let (swapUsed, swapTotal) = getSwapUsage()

        return MemoryInfo(
            totalBytes: totalBytes,
            usedBytes: used,
            wiredBytes: wired,
            compressedBytes: compressed,
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal
        )
    }

    // MARK: - Private Helpers

    private static func getTotalMemory() -> UInt64 {
        let output = runCommand("/usr/sbin/sysctl", arguments: ["-n", "hw.memsize"])
        return UInt64(output) ?? 0
    }

    private static func getVMStatistics(totalBytes: UInt64) -> (used: UInt64, wired: UInt64, compressed: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0, 0)
        }

        let pageSize = UInt64(vm_kernel_page_size)

        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let speculative = UInt64(stats.speculative_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        // Used memory: active + inactive + wired + speculative + compressor
        let used = min(active + inactive + wired + speculative + compressed, totalBytes)

        return (used, wired, compressed)
    }

    private static func getSwapUsage() -> (used: UInt64, total: UInt64) {
        let output = runCommand("/usr/sbin/sysctl", arguments: ["vm.swapusage"])
        // Output format: "vm.swapusage: total = 2048.00M  used = 1024.00M  free = 1024.00M  ..."
        var swapUsed: UInt64 = 0
        var swapTotal: UInt64 = 0

        if let totalRange = output.range(of: "total\\s*=\\s*([\\d.]+)(\\w+)", options: .regularExpression) {
            swapTotal = parseSwapValue(String(output[totalRange]))
        }
        if let usedRange = output.range(of: "used\\s*=\\s*([\\d.]+)(\\w+)", options: .regularExpression) {
            swapUsed = parseSwapValue(String(output[usedRange]))
        }

        return (swapUsed, swapTotal)
    }

    private static func parseSwapValue(_ text: String) -> UInt64 {
        // Extract numeric value and unit from strings like "total = 2048.00M"
        let pattern = "([\\d.]+)(\\w+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3 else {
            return 0
        }

        let numberRange = Range(match.range(at: 1), in: text)!
        let unitRange = Range(match.range(at: 2), in: text)!

        guard let value = Double(String(text[numberRange])) else { return 0 }
        let unit = String(text[unitRange]).uppercased()

        let multiplier: Double
        switch unit {
        case "K": multiplier = 1024
        case "M": multiplier = 1024 * 1024
        case "G": multiplier = 1024 * 1024 * 1024
        case "T": multiplier = 1024 * 1024 * 1024 * 1024
        default: multiplier = 1
        }

        return UInt64(value * multiplier)
    }

    private static func runCommand(_ command: String, arguments: [String] = []) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
