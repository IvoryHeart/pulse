import Foundation

/// Monitors active network connections via netstat/lsof
public struct ConnectionMonitor {

    public struct Connection: Sendable, Codable {
        public let protocol_: String
        public let localAddress: String
        public let localPort: String
        public let remoteAddress: String
        public let remotePort: String
        public let state: String
        public let pid: Int32?
        public let processName: String?
    }

    /// Get active network connections (established TCP)
    public static func getConnections(includeListening: Bool = false) -> [Connection] {
        let output = runCommand("/usr/sbin/netstat", arguments: ["-an", "-p", "tcp"])
        var connections: [Connection] = []

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("tcp") else { continue }

            if let conn = parseNetstatLine(trimmed) {
                if includeListening || conn.state == "ESTABLISHED" {
                    connections.append(conn)
                }
            }
        }

        return connections
    }

    /// Get connections with process name attribution using lsof (more expensive).
    public static func getConnectionsWithProcesses() -> [Connection] {
        let output = runCommand("/usr/sbin/lsof", arguments: ["-i", "-n", "-P", "-F", "pcnPt"])
        var connections: [Connection] = []
        var currentPid: Int32 = 0
        var currentName: String = ""
        var currentProto: String = "tcp"

        for line in output.components(separatedBy: "\n") {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())

            switch prefix {
            case "p":
                currentPid = Int32(value) ?? 0
            case "c":
                currentName = value
            case "P":
                currentProto = value.lowercased()
            case "n":
                if value.contains("->") {
                    let sides = value.split(separator: ">")
                    if sides.count == 2 {
                        let local = String(sides[0].dropLast()) // remove '-'
                        let remote = String(sides[1])
                        let (localAddr, localPort) = splitHostPort(local)
                        let (remoteAddr, remotePort) = splitHostPort(remote)
                        connections.append(Connection(
                            protocol_: currentProto,
                            localAddress: localAddr,
                            localPort: localPort,
                            remoteAddress: remoteAddr,
                            remotePort: remotePort,
                            state: "ESTABLISHED",
                            pid: currentPid,
                            processName: currentName
                        ))
                    }
                }
            default:
                break
            }
        }
        return connections
    }

    /// Get a summary of connections grouped by remote host
    public static func getConnectionSummary() -> [(host: String, count: Int, ports: [String])] {
        let conns = getConnections()
        var grouped: [String: [String]] = [:]

        for conn in conns {
            let host = conn.remoteAddress
            grouped[host, default: []].append(conn.remotePort)
        }

        return grouped.map { (host: $0.key, count: $0.value.count, ports: Array(Set($0.value))) }
            .sorted { $0.count > $1.count }
    }

    private static func parseNetstatLine(_ line: String) -> Connection? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 6 else { return nil }

        let proto = String(parts[0])
        let localFull = String(parts[3])
        let remoteFull = String(parts[4])
        let state = parts.count > 5 ? String(parts[5]) : ""

        let (localAddr, localPort) = splitAddressPort(localFull)
        let (remoteAddr, remotePort) = splitAddressPort(remoteFull)

        var pid: Int32? = nil
        if let lastPart = parts.last, let p = Int32(lastPart) {
            pid = p
        }

        return Connection(
            protocol_: proto,
            localAddress: localAddr,
            localPort: localPort,
            remoteAddress: remoteAddr,
            remotePort: remotePort,
            state: state,
            pid: pid,
            processName: nil
        )
    }

    private static func splitAddressPort(_ addressPort: String) -> (String, String) {
        if let lastDot = addressPort.lastIndex(of: ".") {
            let addr = String(addressPort[addressPort.startIndex..<lastDot])
            let port = String(addressPort[addressPort.index(after: lastDot)...])
            return (addr, port)
        }
        return (addressPort, "*")
    }

    private static func splitHostPort(_ hostPort: String) -> (String, String) {
        if let lastColon = hostPort.lastIndex(of: ":") {
            return (String(hostPort[..<lastColon]), String(hostPort[hostPort.index(after: lastColon)...]))
        }
        return (hostPort, "*")
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
