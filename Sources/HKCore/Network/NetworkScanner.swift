import Foundation

/// Discovers devices on the local network using ARP table
public struct NetworkScanner {

    public struct Device: Sendable {
        public let ipAddress: String
        public let macAddress: String
        public let hostname: String?
        public let interface: String
    }

    /// Get devices from ARP table (no scanning needed, passive discovery)
    public static func getARPDevices() -> [Device] {
        let output = runCommand("/usr/sbin/arp", arguments: ["-a"])
        var devices: [Device] = []

        for line in output.components(separatedBy: "\n") {
            if let device = parseARPLine(line) {
                devices.append(device)
            }
        }

        return devices
    }

    private static func parseARPLine(_ line: String) -> Device? {
        // Format: "? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]"
        // or: "hostname (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]"
        guard line.contains(" at ") else { return nil }

        // Extract IP
        guard let ipStart = line.firstIndex(of: "("),
              let ipEnd = line.firstIndex(of: ")") else { return nil }
        let ip = String(line[line.index(after: ipStart)..<ipEnd])

        // Extract hostname (before the IP)
        let hostname: String?
        let beforeIP = line[line.startIndex..<ipStart].trimmingCharacters(in: .whitespaces)
        hostname = (beforeIP == "?" || beforeIP.isEmpty) ? nil : beforeIP

        // Extract MAC
        guard let atRange = line.range(of: " at ") else { return nil }
        let afterAt = line[atRange.upperBound...]
        let macParts = afterAt.split(separator: " ")
        let mac = macParts.first.map(String.init) ?? "(incomplete)"

        // Extract interface
        var iface = "unknown"
        if let onRange = line.range(of: " on ") {
            let afterOn = line[onRange.upperBound...]
            iface = String(afterOn.split(separator: " ").first ?? "unknown")
        }

        // Skip incomplete entries
        if mac == "(incomplete)" { return nil }

        return Device(ipAddress: ip, macAddress: mac, hostname: hostname, interface: iface)
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
