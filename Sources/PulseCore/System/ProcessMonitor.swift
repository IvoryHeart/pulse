import Foundation
import Darwin

public struct ProcessMonitor {

    public enum SortCriteria {
        case cpu
        case memory
    }

    // MARK: - Public API

    public static func getTopProcesses(sortBy: SortCriteria = .cpu, limit: Int = 10) -> [PulseProcessInfo] {
        let arguments: [String]
        switch sortBy {
        case .cpu:
            arguments = ["-eo", "pid,pcpu,pmem,rss,comm", "-r"]
        case .memory:
            arguments = ["-eo", "pid,pcpu,pmem,rss,comm", "-m"]
        }

        let output = runCommand("/bin/ps", arguments: arguments)
        let lines = output.components(separatedBy: "\n")

        var processes: [PulseProcessInfo] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip header line and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("PID") {
                continue
            }

            if let process = parsePSLine(trimmed) {
                processes.append(process)
            }

            if processes.count >= limit {
                break
            }
        }

        return processes
    }

    // MARK: - Private Helpers

    private static func parsePSLine(_ line: String) -> PulseProcessInfo? {
        // Fields: PID %CPU %MEM RSS COMMAND
        // The command field may contain spaces, so we split only the first 4 fields
        let components = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
        guard components.count >= 5 else { return nil }

        guard let pid = Int32(components[0]),
              let cpu = Double(components[1]),
              let mem = Double(components[2]),
              let rssKB = UInt64(components[3]) else {
            return nil
        }

        let name = String(components[4])
        // RSS from ps is in kilobytes, convert to bytes
        let rssBytes = rssKB * 1024

        return PulseProcessInfo(
            pid: pid,
            name: name,
            cpuPercent: cpu,
            memPercent: mem,
            rssBytes: rssBytes
        )
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
