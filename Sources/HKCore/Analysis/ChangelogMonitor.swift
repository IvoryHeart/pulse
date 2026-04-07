import Foundation

/// Monitors system state changes - a "git log for your Mac".
/// Tracks applications, launch agents/daemons being added, removed, or modified.
public enum ChangelogMonitor {

    // MARK: - Models

    public struct ChangeEntry: Sendable, Codable {
        public let timestamp: Date
        public let category: Category
        public let action: Action
        public let item: String
        public let details: String?

        public init(timestamp: Date, category: Category, action: Action,
                    item: String, details: String?) {
            self.timestamp = timestamp
            self.category = category
            self.action = action
            self.item = item
            self.details = details
        }
    }

    public enum Category: String, Sendable, Codable {
        case application
        case launchAgent
        case launchDaemon
        case loginItem
        case browserExtension
        case systemPreference
    }

    public enum Action: String, Sendable, Codable {
        case added, removed, modified
    }

    public struct SystemState: Sendable, Codable {
        public let applications: [AppInfo]
        public let launchAgents: [String]
        public let launchDaemons: [String]
        public let timestamp: Date

        public init(applications: [AppInfo], launchAgents: [String],
                    launchDaemons: [String], timestamp: Date) {
            self.applications = applications
            self.launchAgents = launchAgents
            self.launchDaemons = launchDaemons
            self.timestamp = timestamp
        }
    }

    public struct AppInfo: Sendable, Codable {
        public let name: String
        public let bundleId: String?
        public let version: String?
        public let modifiedDate: Date?

        public init(name: String, bundleId: String?, version: String?,
                    modifiedDate: Date?) {
            self.name = name
            self.bundleId = bundleId
            self.version = version
            self.modifiedDate = modifiedDate
        }
    }

    // MARK: - Scanning

    /// Scan the current system state (applications, launch agents, launch daemons).
    /// Read-only, no sudo required.
    public static func scanCurrentState() -> SystemState {
        let apps = scanApplications()
        let agents = scanLaunchAgents()
        let daemons = scanLaunchDaemons()
        return SystemState(
            applications: apps,
            launchAgents: agents,
            launchDaemons: daemons,
            timestamp: Date()
        )
    }

    /// Compare current state against the last saved state and return detected changes.
    public static func detectChanges(store: HealthStore) throws -> [ChangeEntry] {
        let current = scanCurrentState()
        guard let previous = try store.getLastSystemState() else {
            return []
        }

        var changes: [ChangeEntry] = []
        let now = Date()

        // --- Application changes ---
        let prevAppsByName = Dictionary(
            previous.applications.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let currAppsByName = Dictionary(
            current.applications.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for (name, app) in currAppsByName where prevAppsByName[name] == nil {
            let versionStr = app.version.map { " " + $0 } ?? ""
            changes.append(ChangeEntry(
                timestamp: now, category: .application, action: .added,
                item: name, details: "installed" + versionStr
            ))
        }

        for (name, _) in prevAppsByName where currAppsByName[name] == nil {
            changes.append(ChangeEntry(
                timestamp: now, category: .application, action: .removed,
                item: name, details: "removed"
            ))
        }

        for (name, currApp) in currAppsByName {
            if let prevApp = prevAppsByName[name],
               let currVersion = currApp.version,
               let prevVersion = prevApp.version,
               currVersion != prevVersion {
                changes.append(ChangeEntry(
                    timestamp: now, category: .application, action: .modified,
                    item: name, details: prevVersion + " \u{2192} " + currVersion
                ))
            }
        }

        // --- Launch agent changes ---
        let prevAgents = Set(previous.launchAgents)
        let currAgents = Set(current.launchAgents)

        for agent in currAgents.subtracting(prevAgents) {
            changes.append(ChangeEntry(
                timestamp: now, category: .launchAgent, action: .added,
                item: agent, details: "added to LaunchAgents"
            ))
        }
        for agent in prevAgents.subtracting(currAgents) {
            changes.append(ChangeEntry(
                timestamp: now, category: .launchAgent, action: .removed,
                item: agent, details: "removed from LaunchAgents"
            ))
        }

        // --- Launch daemon changes ---
        let prevDaemons = Set(previous.launchDaemons)
        let currDaemons = Set(current.launchDaemons)

        for daemon in currDaemons.subtracting(prevDaemons) {
            changes.append(ChangeEntry(
                timestamp: now, category: .launchDaemon, action: .added,
                item: daemon, details: "added to LaunchDaemons"
            ))
        }
        for daemon in prevDaemons.subtracting(currDaemons) {
            changes.append(ChangeEntry(
                timestamp: now, category: .launchDaemon, action: .removed,
                item: daemon, details: "removed from LaunchDaemons"
            ))
        }

        return changes.sorted { $0.item < $1.item }
    }

    /// Save the current system state snapshot to the database.
    public static func saveCurrentState(store: HealthStore) throws {
        let state = scanCurrentState()
        try store.saveSystemState(state)
    }

    // MARK: - Private scanning helpers

    private static func scanApplications() -> [AppInfo] {
        let fm = FileManager.default
        let dirs = ["/Applications", "/Applications/Utilities"]
        var apps: [AppInfo] = []

        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appPath = dir + "/" + item
                let name = String(item.dropLast(4))
                let plistPath = appPath + "/Contents/Info.plist"

                var bundleId: String?
                var version: String?
                var modifiedDate: Date?

                if let plistData = fm.contents(atPath: plistPath),
                   let plist = try? PropertyListSerialization.propertyList(
                       from: plistData, options: [], format: nil) as? [String: Any] {
                    bundleId = plist["CFBundleIdentifier"] as? String
                    version = plist["CFBundleShortVersionString"] as? String
                }

                if let attrs = try? fm.attributesOfItem(atPath: appPath) {
                    modifiedDate = attrs[.modificationDate] as? Date
                }

                apps.append(AppInfo(
                    name: name,
                    bundleId: bundleId,
                    version: version,
                    modifiedDate: modifiedDate
                ))
            }
        }

        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private static func scanLaunchAgents() -> [String] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let dirs = [
            home + "/Library/LaunchAgents",
            "/Library/LaunchAgents"
        ]
        var agents: [String] = []

        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".plist") {
                agents.append(item)
            }
        }

        return agents.sorted()
    }

    private static func scanLaunchDaemons() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: "/Library/LaunchDaemons") else {
            return []
        }
        return contents.filter { $0.hasSuffix(".plist") }.sorted()
    }
}