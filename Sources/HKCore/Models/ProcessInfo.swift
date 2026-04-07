import Foundation

public struct HKProcessInfo: Sendable, Codable {
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memPercent: Double
    public let rssBytes: UInt64

    public init(pid: Int32, name: String, cpuPercent: Double, memPercent: Double, rssBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memPercent = memPercent
        self.rssBytes = rssBytes
    }

    public var rssFormatted: String {
        ByteFormatter.format(rssBytes)
    }

    /// Extracts a friendly short name from the full path.
    /// "/Applications/Arc.app/.../Browser Helper (Renderer)" -> "Arc (Renderer)"
    /// "/usr/sbin/syslogd" -> "syslogd"
    public var shortName: String {
        if let appRange = name.range(of: "/Applications/") {
            let afterApps = String(name[appRange.upperBound...])
            if let dotApp = afterApps.range(of: ".app") {
                let appName = String(afterApps[afterApps.startIndex..<dotApp.lowerBound])
                if let parenStart = name.lastIndex(of: "("),
                   let parenEnd = name.lastIndex(of: ")") {
                    let helperType = String(name[name.index(after: parenStart)..<parenEnd])
                    return "\(appName) (\(helperType))"
                }
                return appName
            }
        }
        return (name as NSString).lastPathComponent
    }
}
