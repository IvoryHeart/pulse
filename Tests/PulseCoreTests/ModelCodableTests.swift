import Testing
import Foundation
@testable import PulseCore

@Suite("Model Codable round-trips")
struct ModelCodableTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - CPUInfo

    @Test("CPUInfo encode then decode preserves all fields")
    func cpuInfoRoundTrip() throws {
        let original = CPUInfo(
            userPercent: 22.5, systemPercent: 8.3, idlePercent: 69.2,
            loadAverage: (2.5, 3.1, 2.8), coreCount: 10, modelName: "Apple M2 Pro"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(CPUInfo.self, from: data)

        #expect(decoded.userPercent == original.userPercent)
        #expect(decoded.systemPercent == original.systemPercent)
        #expect(decoded.idlePercent == original.idlePercent)
        #expect(decoded.loadAverage.0 == original.loadAverage.0)
        #expect(decoded.loadAverage.1 == original.loadAverage.1)
        #expect(decoded.loadAverage.2 == original.loadAverage.2)
        #expect(decoded.coreCount == original.coreCount)
        #expect(decoded.modelName == original.modelName)
    }

    @Test("CPUInfo JSON uses loadAvg1m/5m/15m keys (not tuple)")
    func cpuInfoJSONKeys() throws {
        let cpu = CPUInfo(
            userPercent: 10, systemPercent: 5, idlePercent: 85,
            loadAverage: (1.5, 2.0, 1.8), coreCount: 8, modelName: "M1"
        )
        let data = try encoder.encode(cpu)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["loadAvg1m"] as? Double == 1.5)
        #expect(json["loadAvg5m"] as? Double == 2.0)
        #expect(json["loadAvg15m"] as? Double == 1.8)
        // There should be no "loadAverage" key since tuples are not codable directly
        #expect(json["loadAverage"] == nil)
    }

    @Test("CPUInfo JSON includes computed usagePercent")
    func cpuInfoUsagePercent() throws {
        let cpu = CPUInfo(
            userPercent: 20, systemPercent: 10, idlePercent: 70,
            loadAverage: (1.0, 1.0, 1.0), coreCount: 8, modelName: "M1"
        )
        let data = try encoder.encode(cpu)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["usagePercent"] as? Double == 30.0)
    }

    // MARK: - MemoryInfo

    @Test("MemoryInfo encode then decode preserves all fields")
    func memoryInfoRoundTrip() throws {
        let original = MemoryInfo(
            totalBytes: 17_179_869_184, usedBytes: 12_000_000_000,
            wiredBytes: 3_000_000_000, compressedBytes: 1_000_000_000,
            swapUsedBytes: 500_000_000, swapTotalBytes: 4_000_000_000
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MemoryInfo.self, from: data)

        #expect(decoded.totalBytes == original.totalBytes)
        #expect(decoded.usedBytes == original.usedBytes)
        #expect(decoded.wiredBytes == original.wiredBytes)
        #expect(decoded.compressedBytes == original.compressedBytes)
        #expect(decoded.swapUsedBytes == original.swapUsedBytes)
        #expect(decoded.swapTotalBytes == original.swapTotalBytes)
    }

    @Test("MemoryInfo JSON includes computed usagePercent and swapPercent")
    func memoryInfoComputedFields() throws {
        let mem = MemoryInfo(
            totalBytes: 16_000_000_000, usedBytes: 8_000_000_000,
            wiredBytes: 2_000_000_000, compressedBytes: 500_000_000,
            swapUsedBytes: 1_000_000_000, swapTotalBytes: 4_000_000_000
        )
        let data = try encoder.encode(mem)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["usagePercent"] as? Double == 50.0)
        #expect(json["swapPercent"] as? Double == 25.0)
    }

    // MARK: - DiskInfo

    @Test("DiskInfo encode then decode preserves all fields")
    func diskInfoRoundTrip() throws {
        let original = DiskInfo(
            totalBytes: 500_000_000_000,
            usedBytes: 350_000_000_000,
            availableBytes: 150_000_000_000
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DiskInfo.self, from: data)

        #expect(decoded.totalBytes == original.totalBytes)
        #expect(decoded.usedBytes == original.usedBytes)
        #expect(decoded.availableBytes == original.availableBytes)
    }

    @Test("DiskInfo JSON includes computed usagePercent")
    func diskInfoUsagePercent() throws {
        let disk = DiskInfo(
            totalBytes: 1_000_000_000_000,
            usedBytes: 700_000_000_000,
            availableBytes: 300_000_000_000
        )
        let data = try encoder.encode(disk)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["usagePercent"] as? Double == 70.0)
    }

    // MARK: - BatteryInfo

    @Test("BatteryInfo encode then decode preserves all fields")
    func batteryInfoRoundTrip() throws {
        let original = BatteryInfo(
            percentage: 87, isCharging: true, isPluggedIn: true,
            cycleCount: 342, health: "92%", available: true
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BatteryInfo.self, from: data)

        #expect(decoded.percentage == original.percentage)
        #expect(decoded.isCharging == original.isCharging)
        #expect(decoded.isPluggedIn == original.isPluggedIn)
        #expect(decoded.cycleCount == original.cycleCount)
        #expect(decoded.health == original.health)
        #expect(decoded.available == original.available)
    }

    // MARK: - ThermalInfo

    @Test("ThermalInfo encode then decode preserves state")
    func thermalInfoRoundTrip() throws {
        for state in [ThermalInfo.State.nominal, .fair, .serious, .critical, .unknown] {
            let original = ThermalInfo(state: state)
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ThermalInfo.self, from: data)
            #expect(decoded.state == original.state)
        }
    }

    @Test("ThermalInfo.State raw values are correct strings")
    func thermalStateRawValues() {
        #expect(ThermalInfo.State.nominal.rawValue == "Nominal")
        #expect(ThermalInfo.State.fair.rawValue == "Fair")
        #expect(ThermalInfo.State.serious.rawValue == "Serious")
        #expect(ThermalInfo.State.critical.rawValue == "Critical")
        #expect(ThermalInfo.State.unknown.rawValue == "Unknown")
    }

    // MARK: - PulseProcessInfo

    @Test("PulseProcessInfo encode then decode preserves all fields")
    func processInfoRoundTrip() throws {
        let original = PulseProcessInfo(
            pid: 1234, name: "/usr/sbin/httpd",
            cpuPercent: 45.7, memPercent: 2.3, rssBytes: 256_000_000
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PulseProcessInfo.self, from: data)

        #expect(decoded.pid == original.pid)
        #expect(decoded.name == original.name)
        #expect(decoded.cpuPercent == original.cpuPercent)
        #expect(decoded.memPercent == original.memPercent)
        #expect(decoded.rssBytes == original.rssBytes)
    }

    // MARK: - HealthSnapshot

    @Test("HealthSnapshot encode then decode preserves all fields")
    func healthSnapshotRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        let original = HealthSnapshot(
            timestamp: timestamp,
            cpu: CPUInfo(userPercent: 15, systemPercent: 5, idlePercent: 80,
                         loadAverage: (1.5, 1.2, 1.0), coreCount: 8, modelName: "M1"),
            memory: MemoryInfo(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000,
                               wiredBytes: 2_000_000_000, compressedBytes: 500_000_000,
                               swapUsedBytes: 0, swapTotalBytes: 4_000_000_000),
            disk: DiskInfo(totalBytes: 500_000_000_000, usedBytes: 200_000_000_000,
                           availableBytes: 300_000_000_000),
            battery: BatteryInfo(percentage: 80, isCharging: false, isPluggedIn: false,
                                 cycleCount: 100, health: "100%", available: true),
            thermal: ThermalInfo(state: .nominal),
            topProcesses: [
                PulseProcessInfo(pid: 1, name: "kernel_task", cpuPercent: 5.0,
                              memPercent: 1.0, rssBytes: 100_000_000)
            ]
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HealthSnapshot.self, from: data)

        #expect(decoded.timestamp == original.timestamp)
        #expect(decoded.cpu.coreCount == original.cpu.coreCount)
        #expect(decoded.cpu.modelName == original.cpu.modelName)
        #expect(decoded.memory.totalBytes == original.memory.totalBytes)
        #expect(decoded.disk.totalBytes == original.disk.totalBytes)
        #expect(decoded.battery.percentage == original.battery.percentage)
        #expect(decoded.thermal.state == original.thermal.state)
        #expect(decoded.topProcesses.count == 1)
        #expect(decoded.topProcesses[0].pid == 1)
    }

    // MARK: - HealthScore

    @Test("HealthScore encode then decode preserves all fields")
    func healthScoreRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        let deduction = ScoreDeduction(
            category: "CPU", label: "High CPU load",
            explanation: "Load avg 8.0 on 8 cores", penalty: 5
        )
        let original = HealthScore(score: 95, deductions: [deduction], timestamp: timestamp)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HealthScore.self, from: data)

        #expect(decoded.score == original.score)
        #expect(decoded.deductions.count == 1)
        #expect(decoded.deductions[0].category == "CPU")
        #expect(decoded.deductions[0].label == "High CPU load")
        #expect(decoded.deductions[0].explanation == "Load avg 8.0 on 8 cores")
        #expect(decoded.deductions[0].penalty == 5)
        #expect(decoded.timestamp == original.timestamp)
    }
}
