import Foundation

/// Network interface and traffic information
public struct NetworkInfo {

    public struct Interface: Sendable, Codable {
        public let name: String
        public let address: String
        public let type: String
        public let isUp: Bool
    }

    public struct TrafficStats: Sendable, Codable {
        public let bytesIn: UInt64
        public let bytesOut: UInt64
        public let packetsIn: UInt64
        public let packetsOut: UInt64
    }

    /// Get active network interfaces with their IPs
    public static func getInterfaces() -> [Interface] {
        let output = runCommand("/sbin/ifconfig", arguments: ["-a"])
        var interfaces: [Interface] = []
        var currentName = ""
        var currentAddr = ""
        var isUp = false

        for line in output.components(separatedBy: "\n") {
            if !line.hasPrefix("\t") && !line.hasPrefix(" ") && line.contains(":") {
                if !currentName.isEmpty && !currentAddr.isEmpty {
                    interfaces.append(Interface(
                        name: currentName,
                        address: currentAddr,
                        type: interfaceType(currentName),
                        isUp: isUp
                    ))
                }
                currentName = String(line.prefix(while: { $0 != ":" }))
                currentAddr = ""
                isUp = line.contains("UP")
            } else if line.contains("inet ") && !line.contains("inet6") {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ")
                if parts.count >= 2 {
                    currentAddr = String(parts[1])
                }
            }
        }
        if !currentName.isEmpty && !currentAddr.isEmpty {
            interfaces.append(Interface(
                name: currentName,
                address: currentAddr,
                type: interfaceType(currentName),
                isUp: isUp
            ))
        }

        return interfaces
    }

    /// Get current Wi-Fi SSID
    public static func getWiFiSSID() -> String? {
        let output = runCommand("/usr/sbin/networksetup", arguments: ["-getairportnetwork", "en0"])
        if let range = output.range(of: "Current Wi-Fi Network: ") {
            return String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Get DNS servers
    public static func getDNSServers() -> [String] {
        let output = runCommand("/usr/sbin/scutil", arguments: ["--dns"])
        var servers: [String] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("nameserver[") {
                let parts = trimmed.split(separator: ":")
                if parts.count >= 2 {
                    let server = parts[1].trimmingCharacters(in: .whitespaces)
                    if !servers.contains(server) {
                        servers.append(server)
                    }
                }
            }
        }
        return servers
    }

    /// Get gateway IP
    public static func getGateway() -> String? {
        let output = runCommand("/usr/sbin/netstat", arguments: ["-rn"])
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 2 && parts[0] == "default" {
                return String(parts[1])
            }
        }
        return nil
    }

    /// Get traffic statistics for a network interface (cumulative since boot).
    public static func getTrafficStats(interface: String = "en0") -> TrafficStats {
        let output = runCommand("/usr/sbin/netstat", arguments: ["-I", interface, "-b"])
        let lines = output.components(separatedBy: "\n")
        guard lines.count >= 2 else {
            return TrafficStats(bytesIn: 0, bytesOut: 0, packetsIn: 0, packetsOut: 0)
        }

        let header = lines[0].split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let ibytesIdx = header.firstIndex(of: "Ibytes")
        let obytesIdx = header.firstIndex(of: "Obytes")
        let ipktsIdx = header.firstIndex(of: "Ipkts")
        let opktsIdx = header.firstIndex(of: "Opkts")

        for line in lines.dropFirst() {
            guard line.contains("<Link#") else { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

            let bytesIn = ibytesIdx.flatMap { $0 < parts.count ? UInt64(parts[$0]) : nil } ?? 0
            let bytesOut = obytesIdx.flatMap { $0 < parts.count ? UInt64(parts[$0]) : nil } ?? 0
            let pktsIn = ipktsIdx.flatMap { $0 < parts.count ? UInt64(parts[$0]) : nil } ?? 0
            let pktsOut = opktsIdx.flatMap { $0 < parts.count ? UInt64(parts[$0]) : nil } ?? 0

            return TrafficStats(bytesIn: bytesIn, bytesOut: bytesOut, packetsIn: pktsIn, packetsOut: pktsOut)
        }

        return TrafficStats(bytesIn: 0, bytesOut: 0, packetsIn: 0, packetsOut: 0)
    }

    private static func interfaceType(_ name: String) -> String {
        if name.hasPrefix("en0") { return "Wi-Fi" }
        if name.hasPrefix("en") { return "Ethernet" }
        if name.hasPrefix("lo") { return "Loopback" }
        if name.hasPrefix("bridge") { return "Bridge" }
        if name.hasPrefix("utun") { return "VPN/Tunnel" }
        if name.hasPrefix("awdl") { return "AirDrop" }
        if name.hasPrefix("llw") { return "Low Latency WLAN" }
        return "Other"
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
