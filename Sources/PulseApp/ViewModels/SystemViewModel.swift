import Foundation
import PulseCore
import Combine

@MainActor
final class SystemViewModel: ObservableObject {
    @Published var cpu: CPUInfo?
    @Published var memory: MemoryInfo?
    @Published var disk: DiskInfo?
    @Published var battery: BatteryInfo?
    @Published var thermal: ThermalInfo?
    @Published var topProcesses: [PulseProcessInfo] = []
    @Published var isLoading = true

    // Health score
    @Published var healthScore: HealthScore?

    // WiFi
    @Published var wifiInfo: WiFiMonitor.WiFiInfo?

    // Network throughput (bytes per second, computed from deltas)
    @Published var bytesInPerSec: UInt64 = 0
    @Published var bytesOutPerSec: UInt64 = 0

    // Network details
    @Published var interfaces: [NetworkInfo.Interface] = []
    @Published var connections: [ConnectionMonitor.Connection] = []
    @Published var connectionCount: Int = 0
    @Published var arpDevices: [NetworkScanner.Device] = []
    @Published var bluetoothInfo: BluetoothMonitor.BluetoothInfo?

    // Insights (fetched from SQLite, less frequently)
    @Published var trendPredictions: [TrendAnalyzer.Prediction] = []
    @Published var appProfiles: [AppProfiler.AppProfile] = []
    @Published var changelogEntries: [ChangelogMonitor.ChangeEntry] = []
    @Published var dbStats: HealthStore.DatabaseStats?
    @Published var insightsLoaded = false

    // Cleanup scanner
    @Published var cleanupReport: CleanupScanner.CleanupReport?
    @Published var isScanning = false

    // Bluetooth connection control
    @Published var btConnectingAddresses: Set<String> = []

    // Gateway IP
    @Published var gatewayIP: String?

    // History for sparklines
    @Published var cpuHistory: [Double] = []
    @Published var memHistory: [Double] = []
    @Published var scoreHistory: [Double] = []
    @Published var downloadHistory: [Double] = []
    @Published var uploadHistory: [Double] = []
    @Published var rssiHistory: [Double] = []

    private var timer: Timer?
    private let maxHistory = 60  // last 60 samples
    private var refreshCount = 0

    // For throughput delta calculation
    private var lastTrafficStats: NetworkInfo.TrafficStats?
    private var lastTrafficTime: Date?

    /// Public accessor for total traffic since boot (used by dashboard)
    var lastTrafficStatsPublic: NetworkInfo.TrafficStats? { lastTrafficStats }

    func startMonitoring(interval: TimeInterval = 3.0) {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let cycle = refreshCount
        refreshCount += 1

        Task.detached {
            let cpu = CPUMonitor.getCPUInfo()
            let memory = MemoryMonitor.getMemoryInfo()
            let disk = DiskMonitor.getDiskInfo()
            let battery = BatteryMonitor.getBatteryInfo()
            let thermal = ThermalMonitor.getThermalInfo()
            let procs = ProcessMonitor.getTopProcesses(sortBy: .cpu, limit: 8)

            let score = HealthScoreCalculator.calculate(
                cpu: cpu, memory: memory, disk: disk,
                thermal: thermal, battery: battery,
                topProcesses: procs
            )

            let wifi = WiFiMonitor.getWiFiInfo()
            let traffic = NetworkInfo.getTrafficStats()
            let interfaces = NetworkInfo.getInterfaces()

            // Expensive operations: only every 5th cycle
            let isExpensiveCycle = (cycle % 5 == 0)
            let connections: [ConnectionMonitor.Connection]? = isExpensiveCycle
                ? ConnectionMonitor.getConnections()
                : nil
            let arpDevices: [NetworkScanner.Device]? = isExpensiveCycle
                ? NetworkScanner.getARPDevices()
                : nil
            let btInfo: BluetoothMonitor.BluetoothInfo? = isExpensiveCycle
                ? BluetoothMonitor.getBluetoothInfo()
                : nil
            let gateway: String? = isExpensiveCycle ? NetworkInfo.getGateway() : nil

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.cpu = cpu
                self.memory = memory
                self.disk = disk
                self.battery = battery
                self.thermal = thermal
                self.topProcesses = procs
                self.healthScore = score
                self.wifiInfo = wifi
                self.interfaces = interfaces
                self.isLoading = false

                if let connections {
                    self.connections = connections
                    self.connectionCount = connections.count
                }
                if let arpDevices {
                    self.arpDevices = arpDevices
                }
                if isExpensiveCycle {
                    self.bluetoothInfo = btInfo
                }
                if let gateway {
                    self.gatewayIP = gateway
                }

                // Compute throughput delta
                if let prev = self.lastTrafficStats, let prevTime = self.lastTrafficTime {
                    let elapsed = Date().timeIntervalSince(prevTime)
                    if elapsed > 0 {
                        let dIn = traffic.bytesIn > prev.bytesIn ? traffic.bytesIn - prev.bytesIn : 0
                        let dOut = traffic.bytesOut > prev.bytesOut ? traffic.bytesOut - prev.bytesOut : 0
                        self.bytesInPerSec = UInt64(Double(dIn) / elapsed)
                        self.bytesOutPerSec = UInt64(Double(dOut) / elapsed)
                    }
                }
                self.lastTrafficStats = traffic
                self.lastTrafficTime = Date()

                // Track history
                self.cpuHistory.append(cpu.usagePercent)
                if self.cpuHistory.count > self.maxHistory { self.cpuHistory.removeFirst() }
                self.memHistory.append(memory.usagePercent)
                if self.memHistory.count > self.maxHistory { self.memHistory.removeFirst() }
                self.scoreHistory.append(Double(score.score))
                if self.scoreHistory.count > self.maxHistory { self.scoreHistory.removeFirst() }
                self.downloadHistory.append(Double(self.bytesInPerSec))
                if self.downloadHistory.count > self.maxHistory { self.downloadHistory.removeFirst() }
                self.uploadHistory.append(Double(self.bytesOutPerSec))
                if self.uploadHistory.count > self.maxHistory { self.uploadHistory.removeFirst() }

                // RSSI history
                if let wifi {
                    self.rssiHistory.append(Double(wifi.rssi))
                    if self.rssiHistory.count > self.maxHistory { self.rssiHistory.removeFirst() }
                }

                // Insights: fetch from DB on first load and every 30th cycle (~90s)
                if cycle == 0 || cycle % 30 == 0 {
                    self.refreshInsights()
                }
            }
        }
    }

    func refreshInsights() {
        Task.detached {
            var predictions: [TrendAnalyzer.Prediction] = []
            var profiles: [AppProfiler.AppProfile] = []
            var changelog: [ChangelogMonitor.ChangeEntry] = []
            var stats: HealthStore.DatabaseStats?

            do {
                let store = HealthStore.shared
                try store.open()
                defer { store.close() }

                predictions = (try? TrendAnalyzer.analyzeTrends(store: store)) ?? []
                profiles = (try? AppProfiler.getProfiles(store: store, days: 7)) ?? []

                try store.createChangelogTables()
                changelog = (try? store.getChangelog(days: 7)) ?? []
                stats = try? store.getDatabaseStats()
            } catch {
                // Non-fatal - insights are optional
            }

            let finalPredictions = predictions
            let finalProfiles = Array(profiles.prefix(10))
            let finalChangelog = changelog
            let finalStats = stats

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.trendPredictions = finalPredictions
                self.appProfiles = finalProfiles
                self.changelogEntries = finalChangelog
                self.dbStats = finalStats
                self.insightsLoaded = true
            }
        }
    }

    // MARK: - Cleanup Scanner

    func scanCleanup() {
        guard !isScanning else { return }
        isScanning = true
        Task.detached {
            let report = CleanupScanner.scan()
            await MainActor.run { [weak self] in
                self?.cleanupReport = report
                self?.isScanning = false
            }
        }
    }

    // MARK: - Bluetooth Controls

    func connectBluetoothDevice(address: String) {
        btConnectingAddresses.insert(address)
        Task.detached {
            _ = BluetoothMonitor.connectDevice(address: address)
            let btInfo = BluetoothMonitor.getBluetoothInfo()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.btConnectingAddresses.remove(address)
                self.bluetoothInfo = btInfo
            }
        }
    }

    func disconnectBluetoothDevice(address: String) {
        btConnectingAddresses.insert(address)
        Task.detached {
            _ = BluetoothMonitor.disconnectDevice(address: address)
            let btInfo = BluetoothMonitor.getBluetoothInfo()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.btConnectingAddresses.remove(address)
                self.bluetoothInfo = btInfo
            }
        }
    }

    // MARK: - Status

    var statusIcon: String {
        if let score = healthScore {
            if score.score < 25 { return "exclamationmark.triangle.fill" }
            if score.score < 50 { return "heart.text.square" }
            if score.score < 75 { return "heart.text.square" }
            return "heart.fill"
        }
        guard let cpu = cpu, let memory = memory, let thermal = thermal else { return "heart" }
        if thermal.state == .critical || thermal.state == .serious { return "flame.fill" }
        if cpu.usagePercent > 80 || memory.usagePercent > 95 { return "exclamationmark.triangle.fill" }
        if cpu.usagePercent > 50 || memory.usagePercent > 85 { return "heart.text.square" }
        return "heart.fill"
    }

    var statusColor: String {
        if let score = healthScore { return score.ratingColor }
        guard let cpu = cpu, let memory = memory else { return "gray" }
        if cpu.usagePercent > 80 || memory.usagePercent > 95 { return "red" }
        if cpu.usagePercent > 50 || memory.usagePercent > 85 { return "orange" }
        return "green"
    }
}
